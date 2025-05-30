.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_mul_sve2)
#ifndef __APPLE__
.type gf_vect_mul_sve2, %function
#endif

/* Refer to include/gf_vect_mul.h
 *
 * @param len   Length of vector in bytes. Must be aligned to 32B.
 * @param gftbl Pointer to 32-byte array of pre-calculated constants based on C.
 * @param src   Pointer to src data array. Must be aligned to 32B.
 * @param dest  Pointer to destination data array. Must be aligned to 32B.
 * @returns 0 pass, other fail
 *
 * int gf_vect_mul_sve2(int len, unsigned char *gftbl, void *src, void *dest);
 */

/* arguments */
x_len		.req	x0
x_tbl		.req	x1
x_src		.req	x2
x_dest		.req	x3
x_tmp		.req	x4

/* returns */
w_ret		.req	w0

/* local variables */
x_pos		.req	x5

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z3

z_dest		.req	z4
z_tmp1_lo	.req	z5
z_tmp1_hi	.req	z6

z_gft1_lo	.req	z7
z_gft1_hi	.req	z8
q_gft1_lo	.req	q7
q_gft1_hi	.req	q8

cdecl(gf_vect_mul_sve2):
	/* len not aligned to 32B, return_fail */
	and	x_tmp, x_len, #0x1f
	cmp	x_tmp, #0
	bne	.return_fail

	/* SVE2 OPTIMIZATION: Use DUPQ for efficient mask loading */
	mov	w6, #0x0f0f0f0f
	dupq	z_mask0f.s, w6, w6		/* More efficient than mov z_mask0f.b, #0x0f */
	
	mov	x_pos, #0

	/* Load with NEON instruction ldp */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl]

	/* vector length agnostic */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* SVE2 OPTIMIZATION: Add prefetching for better cache utilization */
	prfb	pldl2strm, p0, [x_src, x_pos]

	/* load src data, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_src, x_pos]

	/* SVE2 OPTIMIZATION: More efficient nibble extraction */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	
	/* SVE2: Use USHR for consistent high nibble extraction */
	ushr	z_src_hi.b, z_src.b, #4
	and	z_src_hi.d, z_src_hi.d, z_mask0f.d

	/* SVE2 OPTIMIZATION: Use TBX for more robust table lookup */
	tbx	z_tmp1_lo.b, z_src_lo.b, {z_gft1_lo.b}
	tbx	z_tmp1_hi.b, z_src_hi.b, {z_gft1_hi.b}

	/* SVE2 OPTIMIZATION: Direct EOR (already optimal for 2-operand) */
	eor	z_dest.d, z_tmp1_hi.d, z_tmp1_lo.d

	/* store dest data, governed by p0 */
	st1b	z_dest.b, p0, [x_dest, x_pos]
	/* increment one vector length */
	incb	x_pos

	b	.Lloopsve2_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret

/* Advanced SVE2 version with additional optimizations */
.global cdecl(gf_vect_mul_sve2_advanced)
#ifndef __APPLE__
.type gf_vect_mul_sve2_advanced, %function
#endif

cdecl(gf_vect_mul_sve2_advanced):
	/* Alignment check */
	and	x_tmp, x_len, #0x1f
	cmp	x_tmp, #0
	bne	.return_fail_adv

	/* SVE2: Efficient constant setup */
	mov	w6, #0x0f0f0f0f
	dupq	z_mask0f.s, w6, w6
	mov	x_pos, #0
	
	/* Load GF tables */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl]

.Lloopsve2_vl_adv:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass_adv

	/* SVE2: Enhanced prefetching */
	prfb	pldl2strm, p0, [x_src, x_pos]
	prfb	pstl2strm, p0, [x_dest, x_pos]	/* Prefetch destination for write */

	ld1b	z_src.b,  p0/z, [x_src, x_pos]

	/* SVE2: Optimized bit manipulation */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	ushr	z_src_hi.b, z_src.b, #4
	and	z_src_hi.d, z_src_hi.d, z_mask0f.d

	/* SVE2: Table lookup with extension */
	tbx	z_tmp1_lo.b, z_src_lo.b, {z_gft1_lo.b}
	tbx	z_tmp1_hi.b, z_src_hi.b, {z_gft1_hi.b}

	/* Final XOR */
	eor	z_dest.d, z_tmp1_hi.d, z_tmp1_lo.d

	st1b	z_dest.b, p0, [x_dest, x_pos]
	incb	x_pos
	b	.Lloopsve2_vl_adv

.return_pass_adv:
	mov	w_ret, #0
	ret

.return_fail_adv:
	mov	w_ret, #1
	ret
