.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_8vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_8vect_dot_prod_sve2, %function
#endif
/* void gf_8vect_dot_prod_sve2(int len, int vlen, unsigned char *gftbls,
				   unsigned char **src, unsigned char **dest);
 */

/* arguments */
x_len		.req	x0	/* vector length in bytes */
x_vec		.req	x1	/* number of source vectors (ie. data blocks) */
x_tbl		.req	x2	/* pointer to multiplication tables */
x_src		.req	x3	/* pointer to array of source vector pointers */
x_dest		.req	x4	/* pointer to array of destination vector pointers */

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
x_tbl7		.req	x14
x_dest1		.req	x15

/* Callee-saved registers, must be preserved on stack */
x_dest2		.req	x19
x_dest3		.req	x20
x_dest4		.req	x21
x_dest5		.req	x22
x_dest6		.req	x23
x_dest7		.req	x24
x_dest8		.req	x_dest	/* reuse x4 for dest8 pointer */
x_tbl8		.req	x25


/* vectors */
z_mask0f	.req	z0	// Mask for isolating low 4 bits of a byte

// Source data and split nibbles
z_src_in	.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z16	// Use a distinct register for clarity

// Destination accumulators
z_dest1		.req	z3
z_dest2		.req	z27
z_dest3		.req	z28
z_dest4		.req	z29
z_dest5		.req	z30
z_dest6		.req	z31
z_dest7		.req	z8
z_dest8		.req	z16 // Overlaps with z_src_hi, managed by instruction scheduling

// Table registers (d8-d15 / z8-z15 must be preserved)
z_gft1_lo	.req	z4
z_gft1_hi	.req	z5
z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
z_gft3_lo	.req	z19
z_gft3_hi	.req	z20
z_gft4_lo	.req	z21
z_gft4_hi	.req	z22
z_gft5_lo	.req	z23
z_gft5_hi	.req	z24
z_gft6_lo	.req	z25
z_gft6_hi	.req	z26
z_gft7_lo	.req	z6
z_gft7_hi	.req	z7
z_gft8_lo	.req	z9
z_gft8_hi	.req	z10

// Temporary registers for non-destructive SVE2 TBL results
z_tmp_lo_res	.req	z11
z_tmp_hi_res	.req	z12


cdecl(gf_8vect_dot_prod_sve2):
	cmp	x_len, #16
	blt	.return_fail

	// Preserve all required callee-saved registers per ARM64 ABI
	// GPRs: x19-x25
	// FPRs/SIMD: d8-d15 (bottom 64 bits of z8-z15)
	sub	sp, sp, #112
	stp	x19, x20, [sp, #16]
	stp	x21, x22, [sp, #32]
	stp	x23, x24, [sp, #48]
	str	x25,     [sp, #64]
	stp	d8, d9,   [sp, #80]
	stp	d10, d11, [sp, #96]
	stp	d12, d13, [sp, #112-16] // Adjusted for stp range
	stp	d14, d15, [sp, #128-16]

	mov	z_mask0f.b, #0x0f
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3
	ldp	x_dest1, x_dest2, [x_dest, #8*0]
	ldp	x_dest3, x_dest4, [x_dest, #8*2]
	ldp	x_dest5, x_dest6, [x_dest, #8*4]
	ldp	x_dest7, x_dest8, [x_dest, #8*6]

.Lloopsve2_8v_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, #0
	ldr	x_ptr, [x_src, x_vec_i]

	// Clear all destination accumulators
	mov	z_dest1.b, #0
	mov	z_dest2.b, #0
	mov	z_dest3.b, #0
	mov	z_dest4.b, #0
	mov	z_dest5.b, #0
	mov	z_dest6.b, #0
	mov	z_dest7.b, #0
	mov	z_dest8.b, #0

	mov	x_tbl1, x_tbl
	add	x_tbl2, x_tbl1, x_vec, LSL #2
	add	x_tbl3, x_tbl2, x_vec, LSL #2
	add	x_tbl4, x_tbl3, x_vec, LSL #2
	add	x_tbl5, x_tbl4, x_vec, LSL #2
	add	x_tbl6, x_tbl5, x_vec, LSL #2
	add	x_tbl7, x_tbl6, x_vec, LSL #2
	add	x_tbl8, x_tbl7, x_vec, LSL #2

.Lloopsve2_8v_vects:
	ld1b	z_src_in.b, p0/z, [x_ptr, x_pos]

	and	z_src_lo.d, z_src_in.d, z_mask0f.d
	movprfx z_src_hi, z_src_in
	lsr	z_src_hi.b, p0/m, z_src_hi.b, #4

	// Load all GF multiplication tables
	ldp	q4, q5, [x_tbl1], #32
	ldp	q17, q18, [x_tbl2], #32
	ldp	q19, q20, [x_tbl3], #32
	ldp	q21, q22, [x_tbl4], #32
	ldp	q23, q24, [x_tbl5], #32
	ldp	q25, q26, [x_tbl6], #32
	ldp	q6, q7, [x_tbl7], #32
	ldp	q9, q10, [x_tbl8], #32

	// Prefetch for next iteration
	prfb	pldl2keep, p0, [x_tbl1]
	prfb	pldl2keep, p0, [x_tbl2]
	prfb	pldl2keep, p0, [x_tbl3]
	prfb	pldl2keep, p0, [x_tbl4]
	prfb	pldl2keep, p0, [x_tbl5]
	prfb	pldl2keep, p0, [x_tbl6]
	prfb	pldl2keep, p0, [x_tbl7]
	prfb	pldl2keep, p0, [x_tbl8]

	add	x_vec_i, x_vec_i, #8
	ldr	x_ptr, [x_src, x_vec_i]

	// --- OPTIMIZATION: Use non-destructive SVE2 TBL instruction ---
	tbl z_tmp_lo_res.b, {z_gft1_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft1_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest1.d, z_dest1.d, z_tmp_lo_res.d
	tbl z_tmp_lo_res.b, {z_gft2_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft2_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest2.d, z_dest2.d, z_tmp_lo_res.d
	tbl z_tmp_lo_res.b, {z_gft3_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft3_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest3.d, z_dest3.d, z_tmp_lo_res.d
	tbl z_tmp_lo_res.b, {z_gft4_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft4_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest4.d, z_dest4.d, z_tmp_lo_res.d
	tbl z_tmp_lo_res.b, {z_gft5_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft5_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest5.d, z_dest5.d, z_tmp_lo_res.d
	tbl z_tmp_lo_res.b, {z_gft6_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft6_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest6.d, z_dest6.d, z_tmp_lo_res.d
	tbl z_tmp_lo_res.b, {z_gft7_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft7_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest7.d, z_dest7.d, z_tmp_lo_res.d
	tbl z_tmp_lo_res.b, {z_gft8_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft8_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest8.d, z_dest8.d, z_tmp_lo_res.d
	
	cmp	x_vec_i, x_vec
	blt	.Lloopsve2_8v_vects

	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]
	st1b	z_dest4.b, p0, [x_dest4, x_pos]
	st1b	z_dest5.b, p0, [x_dest5, x_pos]
	st1b	z_dest6.b, p0, [x_dest6, x_pos]
	st1b	z_dest7.b, p0, [x_dest7, x_pos]
	st1b	z_dest8.b, p0, [x_dest8, x_pos]

	incb	x_pos, all, mul #1
	b	.Lloopsve2_8v_vl

.return_pass:
	// Restore all callee-saved registers
	ldp	d14, d15, [sp, #128-16]
	ldp	d12, d13, [sp, #112-16]
	ldp	d10, d11, [sp, #96]
	ldp	d8, d9,   [sp, #80]
	ldr	x25,     [sp, #64]
	ldp	x23, x24, [sp, #48]
	ldp	x21, x22, [sp, #32]
	ldp	x19, x20, [sp, #16]
	add	sp, sp, #112

	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret
