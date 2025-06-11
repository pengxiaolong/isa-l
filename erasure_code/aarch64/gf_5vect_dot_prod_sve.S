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

.global cdecl(gf_5vect_dot_prod_sve)
#ifndef __APPLE__
.type gf_5vect_dot_prod_sve, %function
#endif

/* Register definitions */
x_len		.req	x0; x_vec		.req	x1
x_tbl		.req	x2; x_src		.req	x3
x_dest		.req	x4; w_ret		.req	w0
x_vec_i		.req	x5; x_ptr1		.req	x6
x_pos		.req	x7; x_tbl1		.req	x8
x_tbl2		.req	x9; x_tbl3		.req	x10
x_tbl4		.req	x11; x_tbl5		.req	x12
x_dest1		.req	x13; x_dest2		.req	x14
x_dest4		.req	x15; x_ptr2      .req    x16
x_vec_end   .req    x17; x_dest5		.req	x_dest
x_dest3		.req	x19

z_mask0f	.req	z0; z_src1		.req	z1
z_src1_lo	.req	z2; z_src1_hi	.req	z_src1
z_dest1		.req	z3; z_gft1_lo	.req	z4
z_gft1_hi	.req	z5; q_gft1_lo	.req	q4
q_gft1_hi	.req	q5
// Unrolled regs
z_src2      .req    z6; z_src2_lo   .req    z7
z_src2_hi   .req    z_src2
z_gft2_lo	.req	z8; z_gft2_hi	.req	z9
q_gft2_lo	.req	q8; q_gft2_hi	.req	q9
z_gft3_lo	.req	z10; z_gft3_hi	.req	z11
q_gft3_lo	.req	q10; q_gft3_hi	.req	q11
z_gft4_lo	.req	z12; z_gft4_hi	.req	z13
q_gft4_lo	.req	q12; q_gft4_hi	.req	q13
z_gft5_lo	.req	z14; z_gft5_hi	.req	z15
q_gft5_lo	.req	q14; q_gft5_hi	.req	q15

z_gft6_lo	.req	z17; z_gft6_hi	.req	z18
q_gft6_lo	.req	q17; q_gft6_hi	.req	q18
z_gft7_lo	.req	z19; z_gft7_hi	.req	z20
q_gft7_lo	.req	q19; q_gft7_hi	.req	q20
z_gft8_lo	.req	z21; z_gft8_hi	.req	z22
q_gft8_lo	.req	q21; q_gft8_hi	.req	q22
z_gft9_lo	.req	z23; z_gft9_hi	.req	z24
q_gft9_lo	.req	q23; q_gft9_hi	.req	q24
z_gft10_lo	.req	z25; z_gft10_hi	.req	z26
q_gft10_lo	.req	q25; q_gft10_hi	.req	q26

z_dest2		.req	z27; z_dest3		.req	z28
z_dest4		.req	z29; z_dest5		.req	z30

cdecl(gf_5vect_dot_prod_sve):
	cmp	x_len, #16
	blt	.return_fail
	sub	sp, sp, #16
	str	x19, [sp]

	mov	z_mask0f.b, #0x0f
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3
	add	x_vec_end, x_src, x_vec
	ldp	x_dest1, x_dest2, [x_dest, #8*0]
	ldp	x_dest3, x_dest4, [x_dest, #8*2]
	ldr	x_dest5, [x_dest, #8*4]

.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, x_src
	ldr	x_ptr1, [x_vec_i], #8
	mov	z_dest1.b, #0; mov	z_dest2.b, #0
	mov	z_dest3.b, #0; mov	z_dest4.b, #0
	mov	z_dest5.b, #0

	mov	x_tbl1, x_tbl
	add	x_tbl2, x_tbl1, x_vec, LSL #2
	add	x_tbl3, x_tbl2, x_vec, LSL #2
	add	x_tbl4, x_tbl3, x_vec, LSL #2
	add	x_tbl5, x_tbl4, x_vec, LSL #2

.Lloopsve_vl_vects:
	ldr	x_ptr2, [x_vec_i], #8

	ld1b	z_src1.b, p0/z, [x_ptr1, x_pos]
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl1], #32
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl2], #32
	ldp	q_gft3_lo, q_gft3_hi, [x_tbl3], #32
	ldp	q_gft4_lo, q_gft4_hi, [x_tbl4], #32
	ldp	q_gft5_lo, q_gft5_hi, [x_tbl5], #32
	and	z_src1_lo.d, z_src1.d, z_mask0f.d
	lsr	z_src1_hi.b, z_src1.b, #4

	ld1b	z_src2.b, p0/z, [x_ptr2, x_pos]
	ldp	q_gft6_lo, q_gft6_hi, [x_tbl1], #32
	ldp	q_gft7_lo, q_gft7_hi, [x_tbl2], #32
	ldp	q_gft8_lo, q_gft8_hi, [x_tbl3], #32
	ldp	q_gft9_lo, q_gft9_hi, [x_tbl4], #32
	ldp	q_gft10_lo, q_gft10_hi, [x_tbl5], #32
	and	z_src2_lo.d, z_src2.d, z_mask0f.d
	lsr	z_src2_hi.b, z_src2.b, #4

	// Accumulate vector 1
	tbl	z_gft1_lo.b, {z_gft1_lo.b}, z_src1_lo.b; tbl	z_gft1_hi.b, {z_gft1_hi.b}, z_src1_hi.b
	eor	z_dest1.d, z_dest1.d, z_gft1_lo.d; eor	z_dest1.d, z_dest1.d, z_gft1_hi.d
	tbl	z_gft2_lo.b, {z_gft2_lo.b}, z_src1_lo.b; tbl	z_gft2_hi.b, {z_gft2_hi.b}, z_src1_hi.b
	eor	z_dest2.d, z_dest2.d, z_gft2_lo.d; eor	z_dest2.d, z_dest2.d, z_gft2_hi.d
	tbl	z_gft3_lo.b, {z_gft3_lo.b}, z_src1_lo.b; tbl	z_gft3_hi.b, {z_gft3_hi.b}, z_src1_hi.b
	eor	z_dest3.d, z_dest3.d, z_gft3_lo.d; eor	z_dest3.d, z_dest3.d, z_gft3_hi.d
	tbl	z_gft4_lo.b, {z_gft4_lo.b}, z_src1_lo.b; tbl	z_gft4_hi.b, {z_gft4_hi.b}, z_src1_hi.b
	eor	z_dest4.d, z_dest4.d, z_gft4_lo.d; eor	z_dest4.d, z_dest4.d, z_gft4_hi.d
	tbl	z_gft5_lo.b, {z_gft5_lo.b}, z_src1_lo.b; tbl	z_gft5_hi.b, {z_gft5_hi.b}, z_src1_hi.b
	eor	z_dest5.d, z_dest5.d, z_gft5_lo.d; eor	z_dest5.d, z_dest5.d, z_gft5_hi.d

	// Accumulate vector 2
	tbl	z_gft6_lo.b, {z_gft6_lo.b}, z_src2_lo.b; tbl	z_gft6_hi.b, {z_gft6_hi.b}, z_src2_hi.b
	eor	z_dest1.d, z_dest1.d, z_gft6_lo.d; eor	z_dest1.d, z_dest1.d, z_gft6_hi.d
	tbl	z_gft7_lo.b, {z_gft7_lo.b}, z_src2_lo.b; tbl	z_gft7_hi.b, {z_gft7_hi.b}, z_src2_hi.b
	eor	z_dest2.d, z_dest2.d, z_gft7_lo.d; eor	z_dest2.d, z_dest2.d, z_gft7_hi.d
	tbl	z_gft8_lo.b, {z_gft8_lo.b}, z_src2_lo.b; tbl	z_gft8_hi.b, {z_gft8_hi.b}, z_src2_hi.b
	eor	z_dest3.d, z_dest3.d, z_gft8_lo.d; eor	z_dest3.d, z_dest3.d, z_gft8_hi.d
	tbl	z_gft9_lo.b, {z_gft9_lo.b}, z_src2_lo.b; tbl	z_gft9_hi.b, {z_gft9_hi.b}, z_src2_hi.b
	eor	z_dest4.d, z_dest4.d, z_gft9_lo.d; eor	z_dest4.d, z_dest4.d, z_gft9_hi.d
	tbl	z_gft10_lo.b, {z_gft10_lo.b}, z_src2_lo.b; tbl	z_gft10_hi.b, {z_gft10_hi.b}, z_src2_hi.b
	eor	z_dest5.d, z_dest5.d, z_gft10_lo.d; eor	z_dest5.d, z_dest5.d, z_gft10_hi.d

	ldr	x_ptr1, [x_vec_i], #8
	cmp	x_vec_i, x_vec_end
	blt	.Lloopsve_vl_vects

	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]
	st1b	z_dest4.b, p0, [x_dest4, x_pos]
	st1b	z_dest5.b, p0, [x_dest5, x_pos]
	incb	x_pos
	b	.Lloopsve_vl

.return_pass:
	ldr	x19, [sp]
	add	sp, sp, #16
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret