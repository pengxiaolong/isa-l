.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_3vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_3vect_dot_prod_sve2, %function
#endif
/* void gf_3vect_dot_prod_sve2(int len, int vlen, unsigned char *gftbls,
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
x_vec_i		.req	x5	/* source vector index counter */
x_ptr		.req	x6	/* pointer to current source vector */
x_pos		.req	x7	/* position offset within vectors */

x_tbl1		.req	x8	/* base pointer for dest1's tables */
x_tbl2		.req	x9	/* base pointer for dest2's tables */
x_tbl3		.req	x10	/* base pointer for dest3's tables */
x_dest1		.req	x11	/* pointer to dest1 vector */
x_dest2		.req	x12	/* pointer to dest2 vector */
x_dest3		.req	x13	/* pointer to dest3 vector */


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

// Table registers
z_gft1_lo	.req	z4
z_gft1_hi	.req	z5
z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
z_gft3_lo	.req	z19
z_gft3_hi	.req	z20

// Temporary registers for non-destructive SVE2 TBL results
z_tmp1_res	.req	z6
z_tmp2_res	.req	z21
z_tmp3_res	.req	z22


cdecl(gf_3vect_dot_prod_sve2):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f		// z_mask0f = 0x0F0F...0F
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3		// Convert vector count to byte offset for pointer array
	ldp	x_dest1, x_dest2, [x_dest, #8*0]
	ldr	x_dest3, [x_dest, #8*2]

// Outer loop: iterates over vector chunks of SVE vector length (VL)
.Lloopsve2_3v_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, #0			// Reset source vector index
	ldr	x_ptr, [x_src, x_vec_i]		// Load first source vector pointer

	mov	z_dest1.b, #0			// Clear destination accumulator 1
	mov	z_dest2.b, #0			// Clear destination accumulator 2
	mov	z_dest3.b, #0			// Clear destination accumulator 3

	// Set base table pointers for this chunk
	mov	x_tbl1, x_tbl
	add	x_tbl2, x_tbl1, x_vec, LSL #2
	add	x_tbl3, x_tbl2, x_vec, LSL #2

// Inner loop: iterates through all source vectors for the current chunk
.Lloopsve2_3v_vects:
	// Load source data for the current vector chunk
	ld1b	z_src_in.b, p0/z, [x_ptr, x_pos]

	// Split source bytes into low and high 4-bit nibbles
	and	z_src_lo.d, z_src_in.d, z_mask0f.d
	lsr	z_src_hi.b, z_src_in.b, #4


	// Load GF multiplication tables for all three destinations
	ldp	q4, q5, [x_tbl1], #32       // z_gft1_lo, z_gft1_hi
	ldp	q17, q18, [x_tbl2], #32     // z_gft2_lo, z_gft2_hi
	ldp	q19, q20, [x_tbl3], #32     // z_gft3_lo, z_gft3_hi

	// Prefetch tables for the next iteration to hide memory latency
	prfb	pldl2keep, p0, [x_tbl1]
	prfb	pldl2keep, p0, [x_tbl2]
	prfb	pldl2keep, p0, [x_tbl3]

	// Prepare pointer for the next source vector
	add	x_vec_i, x_vec_i, #8
	ldr	x_ptr, [x_src, x_vec_i]

	// --- OPTIMIZATION: Use non-destructive SVE2 TBL instruction ---
	// Destination 1 calculation
	tbl	z_tmp1_res.b, {z_gft1_lo.b, z_gft1_hi.b}, z_src_lo.b
	tbl	z_gft1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor	z_tmp1_res.d, z_tmp1_res.d, z_gft1_hi.d
	eor	z_dest1.d, z_dest1.d, z_tmp1_res.d

	// Destination 2 calculation
	tbl	z_tmp2_res.b, {z_gft2_lo.b, z_gft2_hi.b}, z_src_lo.b
	tbl	z_gft2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor	z_tmp2_res.d, z_tmp2_res.d, z_gft2_hi.d
	eor	z_dest2.d, z_dest2.d, z_tmp2_res.d

	// Destination 3 calculation
	tbl	z_tmp3_res.b, {z_gft3_lo.b, z_gft3_hi.b}, z_src_lo.b
	tbl	z_gft3_hi.b, {z_gft3_hi.b}, z_src_hi.b
	eor	z_tmp3_res.d, z_tmp3_res.d, z_gft3_hi.d
	eor	z_dest3.d, z_dest3.d, z_tmp3_res.d

	cmp	x_vec_i, x_vec
	blt	.Lloopsve2_3v_vects
// End of inner loop

	// Store the final accumulated results for the processed chunk
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]

	incb	x_pos, all, mul #1	// Increment position by one vector length
	b	.Lloopsve2_3v_vl
// End of outer loop

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret