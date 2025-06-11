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

.global cdecl(gf_6vect_dot_prod_sve)
#ifndef __APPLE__
.type gf_6vect_dot_prod_sve, %function
#endif

/* arguments */
x_len		.req	x0; x_vec		.req	x1
x_tbl		.req	x2; x_src		.req	x3
x_dest		.req	x4; w_ret		.req	w0
/* local variables */
x_vec_i		.req	x5; x_ptr1		.req	x6
x_pos		.req	x7; x_tbl1		.req	x8
x_tbl2		.req	x9; x_tbl3		.req	x10
x_tbl4		.req	x11; x_tbl5		.req	x12
x_tbl6		.req	x13; x_dest1		.req	x14
x_dest2		.req	x15; x_ptr2      .req    x16
x_vec_end   .req    x17; x_dest6		.req	x_dest
x_dest3		.req	x19; x_dest4		.req	x20
x_dest5		.req	x21

/* vectors */
z_mask0f	.req	z0; z_src1		.req	z1
z_src1_lo	.req	z2; z_src1_hi	.req	z_src1
z_dest1		.req	z3; z_gft1_lo	.req	z4
z_gft1_hi	.req	z5; q_gft1_lo	.req	q4
q_gft1_hi	.req	q5; z_src2      .req    z6
z_src2_lo   .req    z7; z_src2_hi   .req    z_src2

z_gft2_lo	.req	z8; z_gft2_hi	.req	z9
z_gft3_lo	.req	z10; z_gft3_hi	.req	z11
z_gft4_lo	.req	z12; z_gft4_hi	.req	z13
z_gft5_lo	.req	z14; z_gft5_hi	.req	z15
z_gft6_lo	.req	z16; z_gft6_hi	.req	z17
z_gft7_lo	.req	z18; z_gft7_hi	.req	z19
z_gft8_lo	.req	z20; z_gft8_hi	.req	z21
z_gft9_lo	.req	z22; z_gft9_hi	.req	z23
z_gft10_lo	.req	z24; z_gft10_hi	.req	z25
z_gft11_lo	.req	z26; z_gft11_hi	.req	z27
z_gft12_lo	.req	z28; z_gft12_hi	.req	z29

z_dest2		.req	z27; z_dest3		.req	z28
z_dest4		.req	z29; z_dest5		.req	z30
z_dest6		.req	z31

cdecl(gf_6vect_dot_prod_sve):
	cmp	x_len, #16
	blt	.return_fail

	sub	sp, sp, #32
	stp	x19, x20, [sp]
	str	x21, [sp, #16]

	mov	z_mask0f.b, #0x0f
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3
	add	x_vec_end, x_src, x_vec
	ldp	x_dest1, x_dest2, [x_dest, #8*0]
	ldp	x_dest3, x_dest4, [x_dest, #8*2]
	ldp	x_dest5, x_dest6, [x_dest, #8*4]

.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, x_src
	ldr	x_ptr1, [x_vec_i], #8
	mov	z_dest1.b, #0; mov	z_dest2.b, #0
	mov	z_dest3.b, #0; mov	z_dest4.b, #0
	mov	z_dest5.b, #0; mov	z_dest6.b, #0

	mov	x_tbl1, x_tbl
	add	x_tbl2, x_tbl1, x_vec, LSL #2
	add	x_tbl3, x_tbl2, x_vec, LSL #2
	add	x_tbl4, x_tbl3, x_vec, LSL #2
	add	x_tbl5, x_tbl4, x_vec, LSL #2
	add	x_tbl6, x_tbl5, x_vec, LSL #2

.Lloopsve_vl_vects:
	ldr	x_ptr2, [x_vec_i], #8

	// Load data for vector 1 & 2
	ld1b	z_src1.b, p0/z, [x_ptr1, x_pos]
	ld1b	z_src2.b, p0/z, [x_ptr2, x_pos]
	
	// Load tables for vector 1
	ldp	q4, q5, [x_tbl1], #32
	ldp	q8, q9, [x_tbl2], #32
	ldp	q10, q11, [x_tbl3], #32
	ldp	q12, q13, [x_tbl4], #32
	ldp	q14, q15, [x_tbl5], #32
	ldp	q16, q17, [x_tbl6], #32

	// Load tables for vector 2
	ldp	q18, q19, [x_tbl1], #32
	ldp	q20, q21, [x_tbl2], #32
	ldp	q22, q23, [x_tbl3], #32
	ldp	q24, q25, [x_tbl4], #32
	ldp	q26, q27, [x_tbl5], #32
	ldp	q28, q29, [x_tbl6], #32

	and	z_src1_lo.d, z_src1.d, z_mask0f.d
	lsr	z_src1_hi.b, z_src1.b, #4
	and	z_src2_lo.d, z_src2.d, z_mask0f.d
	lsr	z_src2_hi.b, z_src2.b, #4
	
	// Accumulate vector 1
	tbl z4.b, {z4.b}, z_src1_lo.b; tbl z5.b, {z5.b}, z_src1_hi.b
	eor z_dest1.d, z_dest1.d, z4.d; eor z_dest1.d, z_dest1.d, z5.d
	tbl z8.b, {z8.b}, z_src1_lo.b; tbl z9.b, {z9.b}, z_src1_hi.b
	eor z_dest2.d, z_dest2.d, z8.d; eor z_dest2.d, z_dest2.d, z9.d
	tbl z10.b, {z10.b}, z_src1_lo.b; tbl z11.b, {z11.b}, z_src1_hi.b
	eor z_dest3.d, z_dest3.d, z10.d; eor z_dest3.d, z_dest3.d, z11.d
	tbl z12.b, {z12.b}, z_src1_lo.b; tbl z13.b, {z13.b}, z_src1_hi.b
	eor z_dest4.d, z_dest4.d, z12.d; eor z_dest4.d, z_dest4.d, z13.d
	tbl z14.b, {z14.b}, z_src1_lo.b; tbl z15.b, {z15.b}, z_src1_hi.b
	eor z_dest5.d, z_dest5.d, z14.d; eor z_dest5.d, z_dest5.d, z15.d
	tbl z16.b, {z16.b}, z_src1_lo.b; tbl z17.b, {z17.b}, z_src1_hi.b
	eor z_dest6.d, z_dest6.d, z16.d; eor z_dest6.d, z_dest6.d, z17.d

	// Accumulate vector 2
	tbl z18.b, {z18.b}, z_src2_lo.b; tbl z19.b, {z19.b}, z_src2_hi.b
	eor z_dest1.d, z_dest1.d, z18.d; eor z_dest1.d, z_dest1.d, z19.d
	tbl z20.b, {z20.b}, z_src2_lo.b; tbl z21.b, {z21.b}, z_src2_hi.b
	eor z_dest2.d, z_dest2.d, z20.d; eor z_dest2.d, z_dest2.d, z21.d
	tbl z22.b, {z22.b}, z_src2_lo.b; tbl z23.b, {z23.b}, z_src2_hi.b
	eor z_dest3.d, z_dest3.d, z22.d; eor z_dest3.d, z_dest3.d, z23.d
	tbl z24.b, {z24.b}, z_src2_lo.b; tbl z25.b, {z25.b}, z_src2_hi.b
	eor z_dest4.d, z_dest4.d, z24.d; eor z_dest4.d, z_dest4.d, z25.d
	tbl z26.b, {z26.b}, z_src2_lo.b; tbl z27.b, {z27.b}, z_src2_hi.b
	eor z_dest5.d, z_dest5.d, z26.d; eor z_dest5.d, z_dest5.d, z27.d
	tbl z28.b, {z28.b}, z_src2_lo.b; tbl z29.b, {z29.b}, z_src2_hi.b
	eor z_dest6.d, z_dest6.d, z28.d; eor z_dest6.d, z_dest6.d, z29.d

	ldr	x_ptr1, [x_vec_i], #8
	cmp	x_vec_i, x_vec_end
	blt	.Lloopsve_vl_vects

	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]
	st1b	z_dest4.b, p0, [x_dest4, x_pos]
	st1b	z_dest5.b, p0, [x_dest5, x_pos]
	st1b	z_dest6.b, p0, [x_dest6, x_pos]
	incb	x_pos
	b	.Lloopsve_vl

.return_pass:
	ldr	x21, [sp, #16]
	ldp	x19, x20, [sp]
	add	sp, sp, #32
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret
