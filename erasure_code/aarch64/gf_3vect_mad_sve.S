/**************************************************************
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

.global cdecl(gf_3vect_mad_sve)
#ifndef __APPLE__
.type gf_3vect_mad_sve, %function
#endif

/* gf_3vect_mad_sve(int len, int vec, int vec_i, unsigned char *gftbls,
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
x_dest1		.req	x12

/* vectors */
z_mask0f	.req	z0
z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z_src
z_dest1		.req	z3

// OPTIMIZATION: Use separate temp registers to increase ILP
z_tmp1_lo	.req	z4
z_tmp1_hi	.req	z5
z_gft1_lo	.req	z6
z_gft1_hi	.req	z7
q_gft1_lo	.req	q6
q_gft1_hi	.req	q7
z_tmp2_lo	.req	z8
z_tmp2_hi	.req	z9
z_tmp3_lo	.req	z10
z_tmp3_hi	.req	z11

z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
q_gft2_lo	.req	q17
q_gft2_hi	.req	q18
z_gft3_lo	.req	z19
z_gft3_hi	.req	z20
q_gft3_lo	.req	q19
q_gft3_hi	.req	q20
z_dest2		.req	z27
z_dest3		.req	z28

cdecl(gf_3vect_mad_sve):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f
	add	x_tbl, x_tbl, x_vec_i, LSL #5
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl]
	add	x_tbl, x_tbl, x_vec, LSL #5
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl]
	add	x_tbl, x_tbl, x_vec, LSL #5
	ldp	q_gft3_lo, q_gft3_hi, [x_tbl]

	ldr	x_dest1, [x_dest, #8*0]
	ldr	x_dest2, [x_dest, #8*1]
	ldr	x_dest3, [x_dest, #8*2]
	mov	x_pos, #0

	// --- Optimized Pipelined Loop Structure ---
	// Prime the pipeline by loading the first set of data
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	ld1b	z_src.b,  p0/z, [x_src, x_pos]
	ld1b	z_dest1.b,p0/z, [x_dest1, x_pos]
	ld1b	z_dest2.b,p0/z, [x_dest2, x_pos]
	ld1b	z_dest3.b,p0/z, [x_dest3, x_pos]
	incb	x_pos

.Lloopsve_vl:
	// Split src from *previous* load while *next* loads are in flight
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4

	// Load data for the NEXT iteration to hide latency
	whilelo	p1.b, x_pos, x_len
	ld1b	z_src.b,  p1/z, [x_src, x_pos]
	ld1b	z_dest1.b,p1/z, [x_dest1, x_pos]
	ld1b	z_dest2.b,p1/z, [x_dest2, x_pos]
	ld1b	z_dest3.b,p1/z, [x_dest3, x_pos]

	prfb	pldl1keep, p0, [x_src, x_pos, lsl #2]
	prfb	pldl2strm, p0, [x_dest1, x_pos]
	prfb	pldl2strm, p0, [x_dest2, x_pos]
	prfb	pldl2strm, p0, [x_dest3, x_pos]

	// Compute on the CURRENT data (loaded in the previous iteration)
	tbl	z_tmp1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	tbl	z_tmp2_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	tbl	z_tmp3_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp3_hi.b, {z_gft3_hi.b}, z_src_hi.b

	eor	z_dest1.d, z_tmp1_lo.d, z_dest1.d
	eor	z_dest1.d, z_tmp1_hi.d, z_dest1.d
	eor	z_dest2.d, z_tmp2_lo.d, z_dest2.d
	eor	z_dest2.d, z_tmp2_hi.d, z_dest2.d
	eor	z_dest3.d, z_tmp3_lo.d, z_dest3.d
	eor	z_dest3.d, z_tmp3_hi.d, z_dest3.d

	// Store results from the PREVIOUS iteration
	st1b	z_dest1.b, p0, [x_dest1, x_pos, #-1, mul vl]
	st1b	z_dest2.b, p0, [x_dest2, x_pos, #-1, mul vl]
	st1b	z_dest3.b, p0, [x_dest3, x_pos, #-1, mul vl]

	incb	x_pos
	mov	p0.b, p1.b
	b.first	.Lloopsve_vl

	// --- Finalize pipeline: compute and store the last block ---
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4

	tbl	z_tmp1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor	z_dest1.d, z_tmp1_lo.d, z_dest1.d
	eor	z_dest1.d, z_tmp1_hi.d, z_dest1.d

	tbl	z_tmp2_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor	z_dest2.d, z_tmp2_lo.d, z_dest2.d
	eor	z_dest2.d, z_tmp2_hi.d, z_dest2.d

	tbl	z_tmp3_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp3_hi.b, {z_gft3_hi.b}, z_src_hi.b
	eor	z_dest3.d, z_tmp3_lo.d, z_dest3.d
	eor	z_dest3.d, z_tmp3_hi.d, z_dest3.d

	st1b	z_dest1.b, p0, [x_dest1, x_pos, #-1, mul vl]
	st1b	z_dest2.b, p0, [x_dest2, x_pos, #-1, mul vl]
	st1b	z_dest3.b, p0, [x_dest3, x_pos, #-1, mul vl]

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret