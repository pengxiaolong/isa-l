.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_6vect_mad_sve2)
#ifndef __APPLE__
.type gf_6vect_mad_sve2, %function
#endif

/* gf_6vect_mad_sve2(int len, int vec, int vec_i, unsigned char *gftbls,
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
x_dest3		.req	x8
x_dest4		.req	x9
x_dest5		.req	x10
x_dest6		.req	x11
x_dest1		.req	x12

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z_src

z_dest1		.req	z3

z_tmp_lo	.req	z4
z_tmp_hi	.req	z5

/* SVE2 optimization: Organize registers in consecutive pairs for potential TBL2 usage */
z_gft1_lo	.req	z6
z_gft1_hi	.req	z7

z_gft2_lo	.req	z8
z_gft2_hi	.req	z9

z_gft3_lo	.req	z10
z_gft3_hi	.req	z11

z_gft4_lo	.req	z12
z_gft4_hi	.req	z13

z_gft5_lo	.req	z14
z_gft5_hi	.req	z15

z_gft6_lo	.req	z16
z_gft6_hi	.req	z17

z_dest2		.req	z27
z_dest3		.req	z28
z_dest4		.req	z29
z_dest5		.req	z30
z_dest6		.req	z31

cdecl(gf_6vect_mad_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	
	/* SVE2 optimization: Use more efficient table loading */
	add	x_tbl, x_tbl, x_vec_i, LSL #5	/* x_tbl += x_vec_i * 2^5 */

	/* Load all lookup tables with better cache utilization */
	/* Table 1 */
	ld1rqb	z_gft1_lo.b, p7/z, [x_tbl]
	ld1rqb	z_gft1_hi.b, p7/z, [x_tbl, #16]
	add	x_tbl, x_tbl, x_vec, LSL #5

	/* Table 2 */
	ld1rqb	z_gft2_lo.b, p7/z, [x_tbl]
	ld1rqb	z_gft2_hi.b, p7/z, [x_tbl, #16]
	add	x_tbl, x_tbl, x_vec, LSL #5

	/* Table 3 */
	ld1rqb	z_gft3_lo.b, p7/z, [x_tbl]
	ld1rqb	z_gft3_hi.b, p7/z, [x_tbl, #16]
	add	x_tbl, x_tbl, x_vec, LSL #5

	/* Table 4 */
	ld1rqb	z_gft4_lo.b, p7/z, [x_tbl]
	ld1rqb	z_gft4_hi.b, p7/z, [x_tbl, #16]
	add	x_tbl, x_tbl, x_vec, LSL #5

	/* Table 5 */
	ld1rqb	z_gft5_lo.b, p7/z, [x_tbl]
	ld1rqb	z_gft5_hi.b, p7/z, [x_tbl, #16]
	add	x_tbl, x_tbl, x_vec, LSL #5

	/* Table 6 */
	ld1rqb	z_gft6_lo.b, p7/z, [x_tbl]
	ld1rqb	z_gft6_hi.b, p7/z, [x_tbl, #16]

	/* Load destination pointers */
	ldr	x_dest1, [x_dest, #8*0]		/* pointer to dest1 */
	ldr	x_dest2, [x_dest, #8*1]		/* pointer to dest2 */
	ldr	x_dest3, [x_dest, #8*2]		/* pointer to dest3 */
	ldr	x_dest4, [x_dest, #8*3]		/* pointer to dest4 */
	ldr	x_dest5, [x_dest, #8*4]		/* pointer to dest5 */
	ldr	x_dest6, [x_dest, #8*5]		/* pointer to dest6 */

	mov	x_pos, #0

	/* Set up predicate for all active elements */
	ptrue	p7.b

	/* vector length agnostic */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* Enhanced prefetching strategy */
	prfb	pldl1strm, p0, [x_dest1, x_pos, #64]
	prfb	pldl1strm, p0, [x_dest2, x_pos, #64]
	prfb	pldl1strm, p0, [x_dest3, x_pos, #64]

	/* load src data, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_src, x_pos]

	/* split 4-bit lo; 4-bit hi */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4

	/* load dest data, governed by p0 - batch load for better memory bandwidth */
	ld1b	z_dest1.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2.b, p0/z, [x_dest2, x_pos]
	ld1b	z_dest3.b, p0/z, [x_dest3, x_pos]

	/* Continue prefetching */
	prfb	pldl1strm, p0, [x_dest4, x_pos, #64]
	prfb	pldl1strm, p0, [x_dest5, x_pos, #64]
	prfb	pldl1strm, p0, [x_dest6, x_pos, #64]

	/* Load remaining dest data */
	ld1b	z_dest4.b, p0/z, [x_dest4, x_pos]
	ld1b	z_dest5.b, p0/z, [x_dest5, x_pos]
	ld1b	z_dest6.b, p0/z, [x_dest6, x_pos]

	/* SVE2 optimized dest1 - Use EOR3 for 3-way XOR */
	tbl	z_tmp_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor3	z_dest1.d, z_dest1.d, z_tmp_lo.d, z_tmp_hi.d

	/* SVE2 optimized dest2 */
	tbl	z_tmp_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor3	z_dest2.d, z_dest2.d, z_tmp_lo.d, z_tmp_hi.d

	/* SVE2 optimized dest3 */
	tbl	z_tmp_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft3_hi.b}, z_src_hi.b
	eor3	z_dest3.d, z_dest3.d, z_tmp_lo.d, z_tmp_hi.d

	/* SVE2 optimized dest4 */
	tbl	z_tmp_lo.b, {z_gft4_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft4_hi.b}, z_src_hi.b
	eor3	z_dest4.d, z_dest4.d, z_tmp_lo.d, z_tmp_hi.d

	/* SVE2 optimized dest5 */
	tbl	z_tmp_lo.b, {z_gft5_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft5_hi.b}, z_src_hi.b
	eor3	z_dest5.d, z_dest5.d, z_tmp_lo.d, z_tmp_hi.d

	/* SVE2 optimized dest6 */
	tbl	z_tmp_lo.b, {z_gft6_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft6_hi.b}, z_src_hi.b
	eor3	z_dest6.d, z_dest6.d, z_tmp_lo.d, z_tmp_hi.d

	/* Store all dest data with optimized ordering */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]
	st1b	z_dest4.b, p0, [x_dest4, x_pos]
	st1b	z_dest5.b, p0, [x_dest5, x_pos]
	st1b	z_dest6.b, p0, [x_dest6, x_pos]

	/* increment one vector length */
	incb	x_pos

	b	.Lloopsve2_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret