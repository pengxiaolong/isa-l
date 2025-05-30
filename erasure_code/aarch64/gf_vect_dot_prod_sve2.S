.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_vect_dot_prod_sve2, %function
#endif
/* void gf_vect_dot_prod_sve2(int len, int vlen, unsigned char *gftbls,
				unsigned char **src, unsigned char *dest);
 */

/* arguments */
x_len		.req	x0	/* vector length */
x_vec		.req	x1	/* number of source vectors (ie. data blocks) */
x_tbl		.req	x2
x_src		.req	x3
x_dest1		.req	x4

/* returns */
w_ret		.req	w0

/* local variables */
x_vec_i		.req	x5
x_ptr		.req	x6
x_pos		.req	x7
x_tbl1		.req	x8

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z3

z_dest		.req	z4

z_gft1_lo	.req	z5
z_gft1_hi	.req	z6
q_gft1_lo	.req	q5
q_gft1_hi	.req	q6

z_tmp		.req	z7		/* temporary register for SVE2 ops */

cdecl(gf_vect_dot_prod_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3

/* Loop 1: x_len, vector length */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	z_dest.b, #0			/* clear z_dest */
	mov	x_vec_i, #0			/* clear x_vec_i */
	mov	x_tbl1, x_tbl			/* reset x_tbl1 */

/* Loop 2: x_vec, number of source vectors (ie. data blocks) */
.Lloopsve2_vl_vects:
	ldr	x_ptr, [x_src, x_vec_i]		/* x_ptr: src base addr. */
	/* load src data, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_ptr, x_pos]	/* load from: src base + pos offset */

	add	x_vec_i, x_vec_i, #8		/* move x_vec_i to next */

	/* load gf_table */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl1], #32	/* x_tbl1 is added by #32
							   for each src vect */

	/* SVE2 OPTIMIZATION: Use BEXT to extract nibbles more efficiently */
	/* Create immediate for nibble extraction pattern */
	mov	z_tmp.b, #0x04			/* bit position pattern for high nibble */
	
	/* Extract low nibbles using BEXT (bit extract) - SVE2 instruction */
	bext	z_src_lo.b, z_src.b, z_mask0f.b
	
	/* Extract high nibbles using BEXT with shift pattern */
	bext	z_src_hi.b, z_src.b, z_tmp.b
	lsr	z_src_hi.b, z_src_hi.b, #4	/* Still need shift for proper alignment */

	/* SVE2 OPTIMIZATION: Use TBX for more efficient table lookup */
	/* TBX (table lookup with extension) can handle out-of-range indices better */
	tbx	z_gft1_lo.b, z_src_lo.b, {z_gft1_lo.b}
	tbx	z_gft1_hi.b, z_src_hi.b, {z_gft1_hi.b}

	/* SVE2 OPTIMIZATION: Use EOR3 for three-way XOR in single instruction */
	eor3	z_dest.d, z_dest.d, z_gft1_lo.d, z_gft1_hi.d

	cmp	x_vec_i, x_vec
	blt	.Lloopsve2_vl_vects

	/* end of Loop 2 */
	/* store dest data, governed by p0 */
	st1b	z_dest.b, p0, [x_dest1, x_pos]
	/* increment one vector length */
	incb	x_pos

	b	.Lloopsve2_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret
