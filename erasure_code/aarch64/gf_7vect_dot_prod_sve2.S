.text
.align		6
.arch		armv9-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_7vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_7vect_dot_prod_sve2, %function
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
z_dest1		.req	z3
z_dest2		.req	z4
z_dest3		.req	z5
z_dest4		.req	z6
z_dest5		.req	z7
z_dest6		.req	z16     /* Use call-clobbered registers */
z_dest7		.req	z17
z_gft1_lo	.req	z18
z_gft1_hi	.req	z19
z_gft2_lo	.req	z20
z_gft2_hi	.req	z21
z_gft3_lo	.req	z22
z_gft3_hi	.req	z23
z_gft4_lo	.req	z24
z_gft4_hi	.req	z25
z_gft5_lo	.req	z26
z_gft5_hi	.req	z27
z_gft6_lo	.req	z28
z_gft6_hi	.req	z29
z_gft7_lo	.req	z30
z_gft7_hi	.req	z31

cdecl(gf_7vect_dot_prod_sve2):
	cmp	x_len, #16
	blt	.return_fail

	/* Save preserved registers */
	stp	x19, x20, [sp, #-48]!
	stp	x21, x22, [sp, #16]
	str	x23, [sp, #32]

	mov	z_mask0f.b, #0x0f        /* 0x0F mask */
	index	z_pos.b, #0, #1          /* Create position vector */
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3          /* x_vec *= 8 */
	ldp	x_dest1, x_dest2, [x_dest]
	ldp	x_dest3, x_dest4, [x_dest, #16]
	ldp	x_dest5, x_dest6, [x_dest, #32]
	ldr	x_dest7, [x_dest, #48]    /* Load all seven destinations */

.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	z_dest1.b, #0            /* Clear accumulators */
	mov	z_dest2.b, #0
	mov	z_dest3.b, #0
	mov	z_dest4.b, #0
	mov	z_dest5.b, #0
	mov	z_dest6.b, #0
	mov	z_dest7.b, #0
	mov	x_vec_i, #0               /* Reset vector index */
	mov	x_tbl1, x_tbl             /* Reset table pointers */
	add	x_tbl2, x_tbl1, x_vec, LSL #2
	add	x_tbl3, x_tbl2, x_vec, LSL #2
	add	x_tbl4, x_tbl3, x_vec, LSL #2
	add	x_tbl5, x_tbl4, x_vec, LSL #2
	add	x_tbl6, x_tbl5, x_vec, LSL #2
	add	x_tbl7, x_tbl6, x_vec, LSL #2

.Lloopsve_vl_vects:
	ldr	x_ptr, [x_src, x_vec_i]   /* Load source pointer */
	ld1b	z_src.b, p0/z, [x_ptr, x_pos]

	/* SVE2 optimized nibble extraction */
	lsr	z_src_hi.b, z_src.b, #4  /* High nibbles */
	and	z_src_lo.d, z_src.d, z_mask0f.d /* Low nibbles */

	/* Load Galois field tables with SVE2 */
	/* Load first 4 tables */
	ld4b	{z_gft1_lo.b, z_gft2_lo.b, z_gft3_lo.b, z_gft4_lo.b}, p0/z, [x_tbl1]
	ld4b	{z_gft1_hi.b, z_gft2_hi.b, z_gft3_hi.b, z_gft4_hi.b}, p0/z, [x_tbl1, #4, mul vl]
	/* Load next 3 tables */
	ld3b	{z_gft5_lo.b, z_gft6_lo.b, z_gft7_lo.b}, p0/z, [x_tbl5]
	ld3b	{z_gft5_hi.b, z_gft6_hi.b, z_gft7_hi.b}, p0/z, [x_tbl5, #3, mul vl]

	/* Advance table pointers */
	add	x_tbl1, x_tbl1, #128
	add	x_tbl2, x_tbl2, #128
	add	x_tbl3, x_tbl3, #128
	add	x_tbl4, x_tbl4, #128
	add	x_tbl5, x_tbl5, #96
	add	x_tbl6, x_tbl6, #96
	add	x_tbl7, x_tbl7, #96

	/* GF multiply-accumulate for all 7 destinations */
	tbl	z_gft1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_gft1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor	z_dest1.d, z_dest1.d, z_gft1_lo.d
	eor	z_dest1.d, z_dest1.d, z_gft1_hi.d

	tbl	z_gft2_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_gft2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor	z_dest2.d, z_dest2.d, z_gft2_lo.d
	eor	z_dest2.d, z_dest2.d, z_gft2_hi.d

	tbl	z_gft3_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_gft3_hi.b, {z_gft3_hi.b}, z_src_hi.b
	eor	z_dest3.d, z_dest3.d, z_gft3_lo.d
	eor	z_dest3.d, z_dest3.d, z_gft3_hi.d

	tbl	z_gft4_lo.b, {z_gft4_lo.b}, z_src_lo.b
	tbl	z_gft4_hi.b, {z_gft4_hi.b}, z_src_hi.b
	eor	z_dest4.d, z_dest4.d, z_gft4_lo.d
	eor	z_dest4.d, z_dest4.d, z_gft4_hi.d

	tbl	z_gft5_lo.b, {z_gft5_lo.b}, z_src_lo.b
	tbl	z_gft5_hi.b, {z_gft5_hi.b}, z_src_hi.b
	eor	z_dest5.d, z_dest5.d, z_gft5_lo.d
	eor	z_dest5.d, z_dest5.d, z_gft5_hi.d

	tbl	z_gft6_lo.b, {z_gft6_lo.b}, z_src_lo.b
	tbl	z_gft6_hi.b, {z_gft6_hi.b}, z_src_hi.b
	eor	z_dest6.d, z_dest6.d, z_gft6_lo.d
	eor	z_dest6.d, z_dest6.d, z_gft6_hi.d

	tbl	z_gft7_lo.b, {z_gft7_lo.b}, z_src_lo.b
	tbl	z_gft7_hi.b, {z_gft7_hi.b}, z_src_hi.b
	eor	z_dest7.d, z_dest7.d, z_gft7_lo.d
	eor	z_dest7.d, z_dest7.d, z_gft7_hi.d

	/* Prefetch next tables */
	prfb	pldl2keep, p0, [x_tbl1]
	prfb	pldl2keep, p0, [x_tbl2]
	prfb	pldl2keep, p0, [x_tbl3]
	prfb	pldl2keep, p0, [x_tbl4]
	prfb	pldl2keep, p0, [x_tbl5]
	prfb	pldl2keep, p0, [x_tbl6]
	prfb	pldl2keep, p0, [x_tbl7]

	add	x_vec_i, x_vec_i, #8      /* Next source vector */
	cmp	x_vec_i, x_vec
	blt	.Lloopsve_vl_vects

	/* Non-temporal stores */
	stnt1b	z_dest1.b, p0, [x_dest1, x_pos]
	stnt1b	z_dest2.b, p0, [x_dest2, x_pos]
	stnt1b	z_dest3.b, p0, [x_dest3, x_pos]
	stnt1b	z_dest4.b, p0, [x_dest4, x_pos]
	stnt1b	z_dest5.b, p0, [x_dest5, x_pos]
	stnt1b	z_dest6.b, p0, [x_dest6, x_pos]
	stnt1b	z_dest7.b, p0, [x_dest7, x_pos]

	/* Increment position */
	incb	x_pos, ALL, MUL #1
	b	.Lloopsve_vl

.return_pass:
	/* Restore preserved registers */
	ldr	x23, [sp, #32]
	ldp	x21, x22, [sp, #16]
	ldp	x19, x20, [sp], #48
	mov	w0, #0
	ret

.return_fail:
	mov	w0, #1
	ret