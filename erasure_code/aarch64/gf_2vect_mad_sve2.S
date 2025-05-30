.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_2vect_mad_sve2)
#ifndef __APPLE__
.type gf_2vect_mad_sve2, %function
#endif

/* gf_2vect_mad_sve2(int len, int vec, int vec_i, unsigned char *gftbls,
			     unsigned char *src, unsigned char **dest);
 */
/* arguments */
x_len		.req	x0
x_vec		.req	x1
x_vec_i		.req	x2
x_tbl		.req	x3
x_src		.req	x4
x_dest		.req	x5

/* returns */
w_ret		.req	w0

/* local variables */
x_pos		.req	x6
x_dest2		.req	x7
x_dest1		.req	x12
x_tbl2		.req	x13

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z_src

z_dest1		.req	z3

z_tmp_lo	.req	z4
z_tmp_hi	.req	z5

z_gft1_lo	.req	z6
z_gft1_hi	.req	z7
q_gft1_lo	.req	q6
q_gft1_hi	.req	q7

z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
q_gft2_lo	.req	q17
q_gft2_hi	.req	q18

z_dest2		.req	z27

/* SVE2 specific temporaries */
z_temp1		.req	z28
z_temp2		.req	z29

cdecl(gf_2vect_mad_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	
	/* Calculate table addresses */
	add	x_tbl, x_tbl, x_vec_i, LSL #5	/* x_tbl += x_vec_i * 32 */
	add	x_tbl2, x_tbl, x_vec, LSL #5	/* x_tbl2 = x_tbl + vec * 32 */

	/* Load tables using standard LDP (LD1RQ doesn't work for table data) */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl]
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl2]

	ldr	x_dest1, [x_dest, #8*0]		/* pointer to dest1 */
	ldr	x_dest2, [x_dest, #8*1]		/* pointer to dest2 */

	mov	x_pos, #0

	/* vector length agnostic */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* SVE2: Enhanced prefetching with stride patterns */
	prfb	pldl2strm, p0, [x_dest1, x_pos]
	prfb	pldl2strm, p0, [x_dest2, x_pos]
	prfb	pldl1keep, p0, [x_src, x_pos]

	/* load src data, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_src, x_pos]

	/* SVE2: Use more efficient bit field extraction */
	and	z_src_lo.d, z_src.d, z_mask0f.d	/* Keep original method - more reliable */
	lsr	z_src_hi.b, z_src.b, #4

	/* load dest data, governed by p0 */
	ld1b	z_dest1.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2.b, p0/z, [x_dest2, x_pos]

	/* dest1 - table lookups */
	tbl	z_tmp_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft1_hi.b}, z_src_hi.b
	
	/* SVE2: Use EOR3 for three-way XOR operation */
	eor3	z_dest1.d, z_dest1.d, z_tmp_lo.d, z_tmp_hi.d

	/* dest2 - table lookups */
	tbl	z_tmp_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft2_hi.b}, z_src_hi.b
	
	eor3	z_dest2.d, z_dest2.d, z_tmp_lo.d, z_tmp_hi.d

	/* store dest data, governed by p0 */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	
	/* increment one vector length */
	incb	x_pos

	b	.Lloopsve2_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret