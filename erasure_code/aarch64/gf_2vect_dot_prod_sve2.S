.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_2vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_2vect_dot_prod_sve2, %function
#endif
/* void gf_2vect_dot_prod_sve2(int len, int vlen, unsigned char *gftbls,
				   unsigned char **src, unsigned char **dest);
 */

/* arguments */
x_len		.req	x0	/* vector length */
x_vec		.req	x1	/* number of source vectors (ie. data blocks) */
x_tbl		.req	x2
x_src		.req	x3
x_dest		.req	x4

/* returns */
w_ret		.req	w0

/* local variables */
x_vec_i		.req	x5
x_ptr		.req	x6
x_pos		.req	x7

x_tbl1		.req	x8
x_tbl2		.req	x9
x_dest1		.req	x10
x_dest2		.req	x_dest	/* reused */

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z_src

z_dest1		.req	z3

z_gft1_lo	.req	z4
z_gft1_hi	.req	z5
q_gft1_lo	.req	q4
q_gft1_hi	.req	q5

z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
q_gft2_lo	.req	q17
q_gft2_hi	.req	q18

z_dest2		.req	z27

/* SVE2 specific temporaries */
z_temp1		.req	z28
z_temp2		.req	z29

cdecl(gf_2vect_dot_prod_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3
	ldp	x_dest1, x_dest2, [x_dest, #8*0]

/* Loop 1: x_len, vector length */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, #0			/* clear x_vec_i */
	ldr	x_ptr, [x_src, x_vec_i]		/* x_ptr: src base addr. */

	mov	z_dest1.b, #0			/* clear z_dest1 */
	mov	z_dest2.b, #0			/* clear z_dest2 */

	/* gf_tbl base = (x_tbl + dest_idx * x_vec * 32) */
	mov	x_tbl1, x_tbl			/* reset x_tbl1 */
	add	x_tbl2, x_tbl1, x_vec, LSL #2	/* reset x_tbl2 */

/* Loop 2: x_vec, number of source vectors (ie. data blocks) */
.Lloopsve2_vl_vects:
	/* load src data, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_ptr, x_pos]	/* load from: src base + pos offset */
	
	/* split 4-bit lo; 4-bit hi - keep original reliable method */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4

	/* gf_tbl addr: (x_tbl + dest_idx * x_vec * 32) + src_vec_idx * 32 */
	/* load gf_table's using standard method */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl1], #32	/* x_tbl1 is post-added by #32 for each src vect */
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl2], #32

	/* prefetch - SVE2 supports more advanced prefetching */
	prfb	pldl2keep, p0, [x_tbl1, #32]
	prfb	pldl2keep, p0, [x_tbl2, #32]

	/* calc for next */
	add	x_vec_i, x_vec_i, #8		/* move x_vec_i to next */
	ldr	x_ptr, [x_src, x_vec_i]		/* x_ptr: src base addr. */

	/* dest 1 */
	/* table indexing, ie. gf(2^8) multiplication */
	tbl	z_gft1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_gft1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	/* SVE2: Use EOR3 for three-way XOR instead of two separate EORs */
	eor3	z_dest1.d, z_dest1.d, z_gft1_lo.d, z_gft1_hi.d

	/* dest 2 */
	tbl	z_gft2_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_gft2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor3	z_dest2.d, z_dest2.d, z_gft2_lo.d, z_gft2_hi.d

	cmp	x_vec_i, x_vec
	blt	.Lloopsve2_vl_vects
/* end of Loop 2 */

	/* store dest data, governed by p0 */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]

	/* increment one vector length */
	incb	x_pos
	b	.Lloopsve2_vl
/* end of Loop 1 */

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret