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
x_len		.req	x0	/* vector length in bytes */
x_vec		.req	x1	/* number of vectors in total table */
x_vec_i		.req	x2	/* index of current vector */
x_tbl_base	.req	x3	/* pointer to base of all multiplication tables */
x_src		.req	x4	/* pointer to the single source vector */
x_dest_ptr_arr	.req	x5	/* pointer to array of destination vector pointers */

/* returns */
w_ret		.req	w0

/* local variables */
x_pos		.req	x6	/* position offset within vectors */
x_tbl		.req	x_tbl_base /* reuse register for current table pointer */
x_dest2		.req	x7
x_dest3		.req	x8
x_dest4		.req	x9
x_dest5		.req	x10
x_dest6		.req	x11
x_dest1		.req	x12

/* vectors */
z_mask0f	.req	z0	// Mask for isolating low 4 bits of a byte

// Source data and split nibbles
z_src_in	.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z16	// Use a distinct register for clarity

// Destination data registers
z_dest1_inout	.req	z3
z_dest2_inout	.req	z27
z_dest3_inout	.req	z28
z_dest4_inout	.req	z29
z_dest5_inout	.req	z30
z_dest6_inout	.req	z31

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
z_gft5_hi	.req	z15
z_gft6_lo	.req	z17
z_gft6_hi	.req	z18

// SVE2 non-destructive TBL requires temporary registers for lookup results
z_tmp_lo_res	.req	z6
z_tmp_hi_res	.req	z7

cdecl(gf_6vect_mad_sve2):
	cmp	x_len, #16
	blt	.return_fail

	// This function uses more than 3 callee-saved registers via .req directives.
	// According to ARM64 ABI, x19-x28 must be preserved.
	// Note: The original SVE code was missing this, which is a bug.
	sub	sp, sp, #80
	stp	x19, x20, [sp, #16]
	stp	x21, x22, [sp, #32]
	stp	x23, x24, [sp, #48]
	stp	x25, x26, [sp, #64]

	mov	z_mask0f.b, #0x0f		// z_mask0f = 0x0F0F...0F

	// Calculate pointer to the start of the tables for the current vector index
	add	x_tbl, x_tbl_base, x_vec_i, LSL #5 // x_tbl_base + vec_i * 32

	// Load the 32-byte multiplication tables for all six destinations
	ldp	q4, q5, [x_tbl]             // z_gft1_lo, z_gft1_hi
	add	x_tbl, x_tbl, x_vec, LSL #5
	ldp	q8, q9, [x_tbl]             // z_gft2_lo, z_gft2_hi
	add	x_tbl, x_tbl, x_vec, LSL #5
	ldp	q10, q11, [x_tbl]           // z_gft3_lo, z_gft3_hi
	add	x_tbl, x_tbl, x_vec, LSL #5
	ldp	q12, q13, [x_tbl]           // z_gft4_lo, z_gft4_hi
	add	x_tbl, x_tbl, x_vec, LSL #5
	ldp	q14, q15, [x_tbl]           // z_gft5_lo, z_gft5_hi
	add	x_tbl, x_tbl, x_vec, LSL #5
	ldp	q17, q18, [x_tbl]           // z_gft6_lo, z_gft6_hi

	// Load pointers to the six destination buffers
	ldp	x_dest1, x_dest2, [x_dest_ptr_arr, #8*0]
	ldp	x_dest3, x_dest4, [x_dest_ptr_arr, #8*2]
	ldp	x_dest5, x_dest6, [x_dest_ptr_arr, #8*4]

	mov	x_pos, #0

// Loop over vector chunks of SVE vector length (VL)
.Lloopsve2_mad_6v_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	// Prefetch destination data for the next store operation
	prfb	pldl2strm, p0, [x_dest1, x_pos]
	prfb	pldl2strm, p0, [x_dest2, x_pos]
	prfb	pldl2strm, p0, [x_dest3, x_pos]
	prfb	pldl2strm, p0, [x_dest4, x_pos]
	prfb	pldl2strm, p0, [x_dest5, x_pos]
	prfb	pldl2strm, p0, [x_dest6, x_pos]

	// Load all source and destination data for the current vector chunk
	ld1b	z_src_in.b,      p0/z, [x_src, x_pos]
	ld1b	z_dest1_inout.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2_inout.b, p0/z, [x_dest2, x_pos]
	ld1b	z_dest3_inout.b, p0/z, [x_dest3, x_pos]
	ld1b	z_dest4_inout.b, p0/z, [x_dest4, x_pos]
	ld1b	z_dest5_inout.b, p0/z, [x_dest5, x_pos]
	ld1b	z_dest6_inout.b, p0/z, [x_dest6, x_pos]


	// Split source bytes into low and high 4-bit nibbles
	and	z_src_lo.d, z_src_in.d, z_mask0f.d
	lsr	z_src_hi.b, z_src_in.b, #4


	// --- OPTIMIZATION: Use non-destructive SVE2 TBL instruction ---
	// Destination 1
	tbl	z_tmp_lo_res.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi_res.b, {z_gft1_hi.b}, z_src_hi.b
	eor	z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d
	eor	z_dest1_inout.d, z_dest1_inout.d, z_tmp_lo_res.d

	// Destination 2
	tbl	z_tmp_lo_res.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp_hi_res.b, {z_gft2_hi.b}, z_src_hi.b
	eor	z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d
	eor	z_dest2_inout.d, z_dest2_inout.d, z_tmp_lo_res.d
	
	// Destination 3
	tbl	z_tmp_lo_res.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp_hi_res.b, {z_gft3_hi.b}, z_src_hi.b
	eor	z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d
	eor	z_dest3_inout.d, z_dest3_inout.d, z_tmp_lo_res.d

	// Destination 4
	tbl	z_tmp_lo_res.b, {z_gft4_lo.b}, z_src_lo.b
	tbl	z_tmp_hi_res.b, {z_gft4_hi.b}, z_src_hi.b
	eor	z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d
	eor	z_dest4_inout.d, z_dest4_inout.d, z_tmp_lo_res.d
	
	// Destination 5
	tbl	z_tmp_lo_res.b, {z_gft5_lo.b}, z_src_lo.b
	tbl	z_tmp_hi_res.b, {z_gft5_hi.b}, z_src_hi.b
	eor	z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d
	eor	z_dest5_inout.d, z_dest5_inout.d, z_tmp_lo_res.d

	// Destination 6
	tbl	z_tmp_lo_res.b, {z_gft6_lo.b}, z_src_lo.b
	tbl	z_tmp_hi_res.b, {z_gft6_hi.b}, z_src_hi.b
	eor	z_tmp_lo_res.d, z_tmp_lo_res.d, z_tmp_hi_res.d
	eor	z_dest6_inout.d, z_dest6_inout.d, z_tmp_lo_res.d

	// Store all the final updated results for the processed chunk
	st1b	z_dest1_inout.b, p0, [x_dest1, x_pos]
	st1b	z_dest2_inout.b, p0, [x_dest2, x_pos]
	st1b	z_dest3_inout.b, p0, [x_dest3, x_pos]
	st1b	z_dest4_inout.b, p0, [x_dest4, x_pos]
	st1b	z_dest5_inout.b, p0, [x_dest5, x_pos]
	st1b	z_dest6_inout.b, p0, [x_dest6, x_pos]

	// Increment position by one vector length
	incb	x_pos, all, mul #1
	b	.Lloopsve2_mad_6v_vl

.return_pass:
	// Restore callee-saved registers
	ldp	x19, x20, [sp, #16]
	ldp	x21, x22, [sp, #32]
	ldp	x23, x24, [sp, #48]
	ldp	x25, x26, [sp, #64]
	add	sp, sp, #80

	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret
