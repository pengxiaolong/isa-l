.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_2vect_mad_sve2)
#ifndef __APPLE__
.type gf_2vect_mad_sve2, %function
#endif

/* void gf_2vect_mad_sve2(int len, int vec, int vec_i, unsigned char *gftbls,
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
x_dest1		.req	x7	/* pointer to dest1 vector */
x_dest2		.req	x12	/* pointer to dest2 vector */


/* vectors */
z_mask0f	.req	z0	// Mask for isolating low 4 bits of a byte

// Source data and split nibbles
z_src_in	.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z16	// Use a distinct register for clarity

// Destination data registers
z_dest1_inout	.req	z3
z_dest2_inout	.req	z27

// Table registers for dest1
z_gft1_lo	.req	z4
z_gft1_hi	.req	z5
q_gft1_lo	.req	q4
q_gft1_hi	.req	q5

// Table registers for dest2
z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
q_gft2_lo	.req	q17
q_gft2_hi	.req	q18

// SVE2 non-destructive TBL requires temporary registers for lookup results
z_tmp1_lo	.req	z6
z_tmp1_hi	.req	z7
z_tmp2_lo	.req	z19
z_tmp2_hi	.req	z20


cdecl(gf_2vect_mad_sve2):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f		// z_mask0f = 0x0F0F...0F

	// Calculate pointer to the start of the tables for the current vector index
	add	x_tbl, x_tbl_base, x_vec_i, LSL #5 // x_tbl_base + vec_i * 32

	// Load the 32-byte multiplication tables for both destinations
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl]
	add	x_tbl, x_tbl, x_vec, LSL #5	// Add offset for the second set of tables
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl]

	// Load pointers to the two destination buffers
	ldr	x_dest1, [x_dest_ptr_arr, #8*0]
	ldr	x_dest2, [x_dest_ptr_arr, #8*1]

	mov	x_pos, #0

// Loop over vector chunks of SVE vector length (VL)
.Lloopsve2_mad_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	// Prefetch destination data for the next store operation
	prfb	pldl2strm, p0, [x_dest1, x_pos]
	prfb	pldl2strm, p0, [x_dest2, x_pos]

	// Load source and destination data for the current vector chunk
	ld1b	z_src_in.b,    p0/z, [x_src, x_pos]
	ld1b	z_dest1_inout.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2_inout.b, p0/z, [x_dest2, x_pos]

	// Split source bytes into low and high 4-bit nibbles
	and	z_src_lo.d, z_src_in.d, z_mask0f.d
	lsr	z_src_hi.b, z_src_in.b, #4


	// --- OPTIMIZATION: Use non-destructive SVE2 TBL instruction ---
	// Destination 1: Multiply source with table and add to destination
	tbl	z_tmp1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor	z_tmp1_lo.d, z_tmp1_lo.d, z_tmp1_hi.d
	eor	z_dest1_inout.d, z_dest1_inout.d, z_tmp1_lo.d

	// Destination 2: Multiply source with table and add to destination
	tbl	z_tmp2_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor	z_tmp2_lo.d, z_tmp2_lo.d, z_tmp2_hi.d
	eor	z_dest2_inout.d, z_dest2_inout.d, z_tmp2_lo.d


	// Store the final updated results for the processed chunk
	st1b	z_dest1_inout.b, p0, [x_dest1, x_pos]
	st1b	z_dest2_inout.b, p0, [x_dest2, x_pos]

	// Increment position by one vector length
	incb	x_pos, all, mul #1
	b	.Lloopsve2_mad_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret