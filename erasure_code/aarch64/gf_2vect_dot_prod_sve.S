/*************************************************************
  Copyright (c) 2021 Linaro Ltd.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the
      distribution.
    * Neither the name of Huawei Corporation nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**********************************************************************/
.text
.align		6
.arch		armv8-a+sve

#include "../include/aarch64_label.h"

.global cdecl(gf_2vect_dot_prod_sve)
#ifndef __APPLE__
.type gf_2vect_dot_prod_sve, %function
#endif
/* void gf_2vect_dot_prod_sve(int len, int vlen, unsigned char *gftbls,
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
x_ptr1		.req	x6
x_pos		.req	x7
x_tbl1		.req	x8
x_tbl2		.req	x9
x_dest1		.req	x10
x_ptr2      .req    x11
x_vec_end   .req    x12
x_dest2		.req	x_dest	/* reused */

/* vectors */
z_mask0f	.req	z0

z_src1      .req	z1
z_src1_lo   .req	z2
z_src1_hi   .req	z_src1

z_dest1		.req	z3

z_gft1_lo	.req	z4
z_gft1_hi	.req	z5
q_gft1_lo	.req	q4
q_gft1_hi	.req	q5

z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
q_gft2_lo	.req	q17
q_gft2_hi	.req	q18

z_dest2		.req	z27

// Registers for 2nd unrolled loop
z_src2      .req    z6
z_src2_lo   .req    z7
z_src2_hi   .req    z_src2

z_gft3_lo   .req    z8
z_gft3_hi   .req    z9
q_gft3_lo   .req    q8
q_gft3_hi   .req    q9

z_gft4_lo   .req    z19
z_gft4_hi   .req    z20
q_gft4_lo   .req    q19
q_gft4_hi   .req    q20


cdecl(gf_2vect_dot_prod_sve):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3      // x_vec now holds total byte size of pointer array
	add x_vec_end, x_src, x_vec // End address of the source pointer array
	ldp	x_dest1, x_dest2, [x_dest, #8*0]

.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, x_src      // Start pointer for source vector array
	ldr	x_ptr1, [x_vec_i], #8 // Load first src ptr, advance main ptr

	mov	z_dest1.b, #0
	mov	z_dest2.b, #0

	mov	x_tbl1, x_tbl
	add	x_tbl2, x_tbl1, x_vec, LSL #2

.Lloopsve_vl_vects:
	// Load pointer for the *next* vector early to hide latency
	ldr	x_ptr2, [x_vec_i], #8

	// Load and process data for vector 1
	ld1b	z_src1.b, p0/z, [x_ptr1, x_pos]
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl1, #32*0]! // Load table 1, post-inc
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl2, #32*0]! // Load table 2, post-inc

	and	z_src1_lo.d, z_src1.d, z_mask0f.d
	lsr	z_src1_hi.b, z_src1.b, #4

	// Load and process data for vector 2
	ld1b	z_src2.b, p0/z, [x_ptr2, x_pos]
	ldp	q_gft3_lo, q_gft3_hi, [x_tbl1, #32*0]! // Load table 3, post-inc
	ldp	q_gft4_lo, q_gft4_hi, [x_tbl2, #32*0]! // Load table 4, post-inc

	and	z_src2_lo.d, z_src2.d, z_mask0f.d
	lsr	z_src2_hi.b, z_src2.b, #4

	// Prefetch for future loop iterations
	prfb	pldl1keep, p0, [x_tbl1]
	prfb	pldl1keep, p0, [x_tbl2]

	// Perform lookups and accumulations for vector 1
	tbl	z_gft1_lo.b, {z_gft1_lo.b}, z_src1_lo.b
	tbl	z_gft1_hi.b, {z_gft1_hi.b}, z_src1_hi.b
	eor	z_dest1.d, z_dest1.d, z_gft1_lo.d
	eor	z_dest1.d, z_dest1.d, z_gft1_hi.d

	// Perform lookups and accumulations for vector 2
	tbl	z_gft3_lo.b, {z_gft3_lo.b}, z_src2_lo.b
	tbl	z_gft3_hi.b, {z_gft3_hi.b}, z_src2_hi.b
	eor	z_dest1.d, z_dest1.d, z_gft3_lo.d
	eor	z_dest1.d, z_dest1.d, z_gft3_hi.d

	// Lookups and accumulations for the second destination buffer
	tbl	z_gft2_lo.b, {z_gft2_lo.b}, z_src1_lo.b
	tbl	z_gft2_hi.b, {z_gft2_hi.b}, z_src1_hi.b
	eor	z_dest2.d, z_dest2.d, z_gft2_lo.d
	eor	z_dest2.d, z_dest2.d, z_gft2_hi.d

	tbl	z_gft4_lo.b, {z_gft4_lo.b}, z_src2_lo.b
	tbl	z_gft4_hi.b, {z_gft4_hi.b}, z_src2_hi.b
	eor	z_dest2.d, z_dest2.d, z_gft4_lo.d
	eor	z_dest2.d, z_dest2.d, z_gft4_hi.d

	// Next iteration's pointer
	ldr	x_ptr1, [x_vec_i], #8

	cmp	x_vec_i, x_vec_end
	blt	.Lloopsve_vl_vects

	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]

	incb	x_pos
	b	.Lloopsve_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret