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

.global cdecl(gf_vect_dot_prod_sve)
#ifndef __APPLE__
.type gf_vect_dot_prod_sve, %function
#endif

x_len		.req	x0
x_vec		.req	x1
x_tbl		.req	x2
x_src		.req	x3
x_dest1		.req	x4
w_ret		.req	w0
x_vec_i		.req	x5
x_ptr		.req	x6
x_pos		.req	x7
x_tbl1		.req	x8
x_vec_end	.req	x9
z_mask0f	.req	z0
z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z_src
z_dest		.req	z3
z_gft1_lo	.req	z4
z_gft1_hi	.req	z5
q_gft1_lo	.req	q4
q_gft1_hi	.req	q5

cdecl(gf_vect_dot_prod_sve):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3
	add	x_vec_end, x_src, x_vec

.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	z_dest.b, #0
	mov	x_vec_i, x_src
	mov	x_tbl1, x_tbl

	// Prime the loop
	ldr	x_ptr, [x_vec_i], #8
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl1], #32

.Lloopsve_vl_vects:
	ld1b	z_src.b, p0/z, [x_ptr, x_pos]
	// OPTIMIZATION: Load next pointer and table while processing current
	ldr	x_ptr, [x_vec_i], #8
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl1], #32

	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4

	// OPTIMIZATION: Use table data loaded in previous iteration
	tbl	z_gft1_lo.b, {z4.b}, z_src_lo.b
	tbl	z_gft1_hi.b, {z5.b}, z_src_hi.b

	eor	z_dest.d, z_gft1_lo.d, z_dest.d
	eor	z_dest.d, z_gft1_hi.d, z_dest.d

	cmp	x_vec_i, x_vec_end
	blt	.Lloopsve_vl_vects

	// Final computation with last loaded table
	ld1b	z_src.b, p0/z, [x_ptr, x_pos]
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4
	tbl	z_gft1_lo.b, {z4.b}, z_src_lo.b
	tbl	z_gft1_hi.b, {z5.b}, z_src_hi.b
	eor	z_dest.d, z_gft1_lo.d, z_dest.d
	eor	z_dest.d, z_gft1_hi.d, z_dest.d

	st1b	z_dest.b, p0, [x_dest1, x_pos]
	incb	x_pos
	b	.Lloopsve_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret