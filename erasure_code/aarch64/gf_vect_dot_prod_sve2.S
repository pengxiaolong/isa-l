.text
.align		6
.arch		armv9-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_vect_dot_prod_sve2, %function
#endif

/* Arguments */
x_len		.req	x0	/* vector length */
x_vec		.req	x1	/* number of source vectors */
x_tbl		.req	x2
x_src		.req	x3
x_dest		.req	x4

/* Vectors */
z_mask0f	.req	z0
z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z1      /* Reuse z_src */
z_dest		.req	z3
z_gft_lo	.req	z4
z_gft_hi	.req	z5

cdecl(gf_vect_dot_prod_sve2):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f        /* 0x0F mask */
	index	z_pos.b, #0, #1          /* Create position vector */
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3          /* x_vec *= 8 */

.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	z_dest.b, #0            /* Clear accumulator */
	mov	x_vec_i, #0             /* Reset vector index */
	mov	x_tbl1, x_tbl           /* Reset table pointer */

.Lloopsve_vl_vects:
	ldr	x_ptr, [x_src, x_vec_i]  /* Load source pointer */
	ld1b	z_src.b, p0/z, [x_ptr, x_pos]

	/* SVE2 optimized nibble extraction */
	lsr	z_src_hi.b, z_src.b, #4  /* High nibbles */
	and	z_src_lo.d, z_src.d, z_mask0f.d /* Low nibbles */

	/* Load Galois field table with SVE2 */
	ld2b	{z_gft_lo.b, z_gft_hi.b}, p0/z, [x_tbl1]
	add	x_tbl1, x_tbl1, #32       /* Advance table pointer */

	/* GF multiply-accumulate */
	tbl	z_gft_lo.b, {z_gft_lo.b}, z_src_lo.b
	tbl	z_gft_hi.b, {z_gft_hi.b}, z_src_hi.b
	eor	z_dest.d, z_dest.d, z_gft_lo.d
	eor	z_dest.d, z_dest.d, z_gft_hi.d

	add	x_vec_i, x_vec_i, #8      /* Next source vector */
	cmp	x_vec_i, x_vec
	blt	.Lloopsve_vl_vects

	/* Non-temporal store for better cache behavior */
	stnt1b	z_dest.b, p0, [x_dest, x_pos]

	/* Increment position */
	incb	x_pos, ALL, MUL #1
	b	.Lloopsve_vl

.return_pass:
	mov	w0, #0
	ret

.return_fail:
	mov	w0, #1
	ret