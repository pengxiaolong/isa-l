.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_7vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_7vect_dot_prod_sve2, %function
#endif
/* void gf_7vect_dot_prod_sve2(int len, int vlen, unsigned char *gftbls,
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
x_dest7		.req	x_dest	/* reuse x4 for dest7 pointer */


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
z_dest7		.req	z15

// Table registers
z_gft1_lo	.req	z4
z_gft1_hi	.req	z5
z_gft2_lo	.req	z8
z_gft2_hi	.req	z9
z_gft3_lo	.req	z10
z_gft3_hi	.req	z11
z_gft4_lo	.req	z12
z_gft4_hi	.req	z13
z_gft5_lo	.req	z14
z_gft6_lo	.req	z17
z_gft6_hi	.req	z18
z_gft7_lo	.req	z6
z_gft7_hi	.req	z7

// Temporary registers for non-destructive SVE2 TBL results
z_tmp_lo_res	.req	z24
z_tmp_hi_res	.req	z25

cdecl(gf_7vect_dot_prod_sve2):
	cmp	x_len, #16
	blt	.return_fail

	// Preserve callee-saved registers x19-x23
	sub	sp, sp, #48
	stp	x19, x20, [sp]
	stp	x21, x22, [sp, #16]
	str	x23, [sp, #32]


	mov	z_mask0f.b, #0x0f		// z_mask0f = 0x0F0F...0F
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3		// Convert vector count to byte offset
	ldp	x_dest1, x_dest2, [x_dest, #8*0] // x_dest2 = x19
	ldp	x_dest3, x_dest4, [x_dest, #8*2] // x_dest3=x20, x_dest4=x21
	ldp	x_dest5, x_dest6, [x_dest, #8*4] // x_dest5=x22, x_dest6=x23
	ldr	x_dest7, [x_dest, #8*6]

// Outer loop: iterates over vector chunks of SVE vector length (VL)
.Lloopsve2_7v_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, #0			// Reset source vector index
	ldr	x_ptr, [x_src, x_vec_i]		// Load first source vector pointer

	// Clear destination accumulators
	mov	z_dest1.b, #0
	mov	z_dest2.b, #0
	mov	z_dest3.b, #0
	mov	z_dest4.b, #0
	mov	z_dest5.b, #0
	mov	z_dest6.b, #0
	mov	z_dest7.b, #0

	// Set base table pointers for this chunk
	mov	x_tbl1, x_tbl
	add	x_tbl2, x_tbl1, x_vec, LSL #2
	add	x_tbl3, x_tbl2, x_vec, LSL #2
	add	x_tbl4, x_tbl3, x_vec, LSL #2
	add	x_tbl5, x_tbl4, x_vec, LSL #2
	add	x_tbl6, x_tbl5, x_vec, LSL #2
	add	x_tbl7, x_tbl6, x_vec, LSL #2

// Inner loop: iterates through all source vectors for the current chunk
.Lloopsve2_7v_vects:
	// Load source data for the current vector chunk
	ld1b	z_src_in.b, p0/z, [x_ptr, x_pos]

	// Split source bytes into low and high 4-bit nibbles
	and	z_src_lo.d, z_src_in.d, z_mask0f.d
	lsr	z_src_hi.b, z_src_in.b, #4


	// Load all GF multiplication tables
	ldp	q4, q5, [x_tbl1], #32
	ldp	q8, q9, [x_tbl2], #32
	ldp	q10, q11, [x_tbl3], #32
	ldp	q12, q13, [x_tbl4], #32
	ldp	q14, z15.q, [x_tbl5], #32  // z_gft5_hi is z15
	ldp	q17, q18, [x_tbl6], #32
	ldp	q6, q7, [x_tbl7], #32


	// Prefetch tables for the next iteration
	prfb	pldl2keep, p0, [x_tbl1]
	prfb	pldl2keep, p0, [x_tbl2]
	prfb	pldl2keep, p0, [x_tbl3]
	prfb	pldl2keep, p0, [x_tbl4]
	prfb	pldl2keep, p0, [x_tbl5]
	prfb	pldl2keep, p0, [x_tbl6]
	prfb	pldl2keep, p0, [x_tbl7]

	// Prepare pointer for the next source vector
	add	x_vec_i, x_vec_i, #8
	ldr	x_ptr, [x_src, x_vec_i]

	// --- OPTIMIZATION: Use non-destructive SVE2 TBL instruction ---
	// Calculations for all 7 destinations
	tbl	z_tmp_lo_res.b, {z_gft1_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft1_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest1.d, z_dest1.d, z_tmp_lo_res.d
	tbl	z_tmp_lo_res.b, {z_gft2_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft2_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest2.d, z_dest2.d, z_tmp_lo_res.d
	tbl	z_tmp_lo_res.b, {z_gft3_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft3_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest3.d, z_dest3.d, z_tmp_lo_res.d
	tbl	z_tmp_lo_res.b, {z_gft4_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft4_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest4.d, z_dest4.d, z_tmp_lo_res.d
	tbl	z_tmp_lo_res.b, {z_gft5_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft5_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest5.d, z_dest5.d, z_tmp_lo_res.d
	tbl	z_tmp_lo_res.b, {z_gft6_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft6_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest6.d, z_dest6.d, z_tmp_lo_res.d
	tbl	z_tmp_lo_res.b, {z_gft7_lo.b}, z_src_lo.b; tbl z_tmp_hi_res.b, {z_gft7_hi.b}, z_src_hi.b; eor z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d; eor z_dest7.d, z_dest7.d, z_tmp_lo_res.d

	cmp	x_vec_i, x_vec
	blt	.Lloopsve2_7v_vects
// End of inner loop

	// Store the final accumulated results for the processed chunk
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]
	st1b	z_dest4.b, p0, [x_dest4, x_pos]
	st1b	z_dest5.b, p0, [x_dest5, x_pos]
	st1b	z_dest6.b, p0, [x_dest6, x_pos]
	st1b	z_dest7.b, p0, [x_dest7, x_pos]

	incb	x_pos, all, mul #1	// Increment position by one vector length
	b	.Lloopsve2_7v_vl
// End of outer loop

.return_pass:
	// Restore callee-saved registers x19-x23
	ldr	x23, [sp, #32]
	ldp	x21, x22, [sp, #16]
	ldp	x19, x20, [sp]
	add	sp, sp, #48

	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret
