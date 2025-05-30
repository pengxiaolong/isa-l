.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_6vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_6vect_dot_prod_sve2, %function
#endif
/* void gf_6vect_dot_prod_sve2(int len, int vlen, unsigned char *gftbls,
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
x_tbl3		.req	x10
x_tbl4		.req	x11
x_tbl5		.req	x12
x_tbl6		.req	x13
x_dest1		.req	x14
x_dest2		.req	x15
x_dest6		.req	x_dest	/* reused */

/* r16,r17,r18,r29,r30: special role registers, avoided */
/* r19..r29 and SP must be preserved */
x_dest3		.req	x19
x_dest4		.req	x20
x_dest5		.req	x21

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z_src

z_dest1		.req	z3

/* SVE2 optimization: Use consecutive registers for TBL2 operations */
z_gft1_lo	.req	z4
z_gft1_hi	.req	z5
z_gft1_pair	.req	z4	/* z4-z5 pair for TBL2 */

z_gft2_lo	.req	z6
z_gft2_hi	.req	z7
z_gft2_pair	.req	z6	/* z6-z7 pair for TBL2 */

z_gft3_lo	.req	z8
z_gft3_hi	.req	z9
z_gft3_pair	.req	z8	/* z8-z9 pair for TBL2 */

z_gft4_lo	.req	z10
z_gft4_hi	.req	z11
z_gft4_pair	.req	z10	/* z10-z11 pair for TBL2 */

z_gft5_lo	.req	z12
z_gft5_hi	.req	z13
z_gft5_pair	.req	z12	/* z12-z13 pair for TBL2 */

z_gft6_lo	.req	z14
z_gft6_hi	.req	z15
z_gft6_pair	.req	z14	/* z14-z15 pair for TBL2 */

/* Temporary vectors for SVE2 operations */
z_tmp1		.req	z16
z_tmp2		.req	z17

z_dest2		.req	z27
z_dest3		.req	z28
z_dest4		.req	z29
z_dest5		.req	z30
z_dest6		.req	z31

cdecl(gf_6vect_dot_prod_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	/* save r19..r29  */
	sub	sp, sp, #32			/* alignment */
	stp	x19, x20, [sp]
	str	x21, [sp, #16]

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3
	ldp	x_dest1, x_dest2, [x_dest, #8*0]
	ldp	x_dest3, x_dest4, [x_dest, #8*2]
	ldp	x_dest5, x_dest6, [x_dest, #8*4]	/* x_dest6 reuses x_dest */

/* Loop 1: x_len, vector length */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, #0			/* clear x_vec_i */
	ldr	x_ptr, [x_src, x_vec_i]		/* x_ptr: src base addr. */

	mov	z_dest1.b, #0			/* clear z_dest1 */
	mov	z_dest2.b, #0			/* clear z_dest2 */
	mov	z_dest3.b, #0			/* clear z_dest3 */
	mov	z_dest4.b, #0			/* clear z_dest4 */
	mov	z_dest5.b, #0			/* clear z_dest5 */
	mov	z_dest6.b, #0			/* clear z_dest6 */

	/* gf_tbl base = (x_tbl + dest_idx * x_vec * 32) */
	mov	x_tbl1, x_tbl			/* reset x_tbl1 */
	add	x_tbl2, x_tbl1, x_vec, LSL #2	/* reset x_tbl2 */
	add	x_tbl3, x_tbl2, x_vec, LSL #2	/* reset x_tbl3 */
	add	x_tbl4, x_tbl3, x_vec, LSL #2	/* reset x_tbl4 */
	add	x_tbl5, x_tbl4, x_vec, LSL #2	/* reset x_tbl5 */
	add	x_tbl6, x_tbl5, x_vec, LSL #2	/* reset x_tbl6 */

/* Loop 2: x_vec, number of source vectors (ie. data blocks) */
.Lloopsve2_vl_vects:
	/* load src data, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_ptr, x_pos]	/* load from: src base + pos offset */
	
	/* SVE2 optimization: split 4-bit lo; 4-bit hi more efficiently */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4

	/* gf_tbl addr: (x_tbl + dest_idx * x_vec * 32) + src_vec_idx * 32 */
	/* Load all gf_tables at once for better cache utilization */
	ld2b	{z_gft1_lo.b, z_gft1_hi.b}, p0/z, [x_tbl1]
	add	x_tbl1, x_tbl1, #32
	
	ld2b	{z_gft2_lo.b, z_gft2_hi.b}, p0/z, [x_tbl2]
	add	x_tbl2, x_tbl2, #32

	/* prefetch next tables */
	prfb	pldl2keep, p0, [x_tbl1]
	prfb	pldl2keep, p0, [x_tbl2]

	/* calc for next and prefetch */
	add	x_vec_i, x_vec_i, #8		/* move x_vec_i to next */
	ldr	x_ptr, [x_src, x_vec_i]		/* x_ptr: src base addr. */

	/* SVE2 optimization: Use TBL2 for simultaneous lo/hi lookup */
	/* dest 1 - SVE2 TBL2 performs both lookups in one instruction */
	tbl	z_tmp1.b, {z_gft1_lo.b, z_gft1_hi.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft1_lo.b, z_gft1_hi.b}, z_src_hi.b
	/* SVE2 EOR3: 3-way XOR in single instruction */
	eor3	z_dest1.d, z_dest1.d, z_tmp1.d, z_tmp2.d

	/* Load next tables */
	ld2b	{z_gft3_lo.b, z_gft3_hi.b}, p0/z, [x_tbl3]
	add	x_tbl3, x_tbl3, #32
	ld2b	{z_gft4_lo.b, z_gft4_hi.b}, p0/z, [x_tbl4]
	add	x_tbl4, x_tbl4, #32
	
	prfb	pldl2keep, p0, [x_tbl3]
	prfb	pldl2keep, p0, [x_tbl4]

	/* dest 2 - SVE2 optimized */
	tbl	z_tmp1.b, {z_gft2_lo.b, z_gft2_hi.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft2_lo.b, z_gft2_hi.b}, z_src_hi.b
	eor3	z_dest2.d, z_dest2.d, z_tmp1.d, z_tmp2.d

	/* dest 3 - SVE2 optimized */
	tbl	z_tmp1.b, {z_gft3_lo.b, z_gft3_hi.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft3_lo.b, z_gft3_hi.b}, z_src_hi.b
	eor3	z_dest3.d, z_dest3.d, z_tmp1.d, z_tmp2.d

	/* Load final tables */
	ld2b	{z_gft5_lo.b, z_gft5_hi.b}, p0/z, [x_tbl5]
	add	x_tbl5, x_tbl5, #32
	ld2b	{z_gft6_lo.b, z_gft6_hi.b}, p0/z, [x_tbl6]
	add	x_tbl6, x_tbl6, #32
	
	prfb	pldl2keep, p0, [x_tbl5]
	prfb	pldl2keep, p0, [x_tbl6]

	/* dest 4 - SVE2 optimized */
	tbl	z_tmp1.b, {z_gft4_lo.b, z_gft4_hi.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft4_lo.b, z_gft4_hi.b}, z_src_hi.b
	eor3	z_dest4.d, z_dest4.d, z_tmp1.d, z_tmp2.d

	/* dest 5 - SVE2 optimized */
	tbl	z_tmp1.b, {z_gft5_lo.b, z_gft5_hi.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft5_lo.b, z_gft5_hi.b}, z_src_hi.b
	eor3	z_dest5.d, z_dest5.d, z_tmp1.d, z_tmp2.d

	/* dest 6 - SVE2 optimized */
	tbl	z_tmp1.b, {z_gft6_lo.b, z_gft6_hi.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft6_lo.b, z_gft6_hi.b}, z_src_hi.b
	eor3	z_dest6.d, z_dest6.d, z_tmp1.d, z_tmp2.d

	cmp	x_vec_i, x_vec
	blt	.Lloopsve2_vl_vects
/* end of Loop 2 */

	/* store dest data, governed by p0 */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]
	st1b	z_dest4.b, p0, [x_dest4, x_pos]
	st1b	z_dest5.b, p0, [x_dest5, x_pos]
	st1b	z_dest6.b, p0, [x_dest6, x_pos]

	/* increment one vector length */
	incb	x_pos
	b	.Lloopsve2_vl
/* end of Loop 1 */

.return_pass:
	/* restore r19..r29  */
	ldr	x21, [sp, #16]
	ldp	x19, x20, [sp]
	add	sp, sp, #32

	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret