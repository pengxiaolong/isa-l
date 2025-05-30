.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_mul_sve2)
#ifndef __APPLE__
.type gf_vect_mul_sve2, %function
#endif

/* arguments */
x_len		.req	x0
x_tbl		.req	x1
x_src		.req	x2
x_dest		.req	x3
x_tmp		.req	x4

/* returns */
w_ret		.req	w0

/* local variables */
x_pos		.req	x5

/* vectors */
z_mask0f	.req	z0
z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z1
z_dest		.req	z3
z_tmp1_lo	.req	z4
z_tmp1_hi	.req	z3
z_gft1_lo	.req	z6
z_gft1_hi	.req	z7

cdecl(gf_vect_mul_sve2):
	/* len not aligned to 32B, return_fail */
	tst	x_len, #0x1f			/* More efficient test */
	b.ne	.return_fail

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	mov	x_pos, #0

	/* Load with SVE2 instructions */
	ld1b	z_gft1_lo.b, p0/z, [x_tbl]
	add	x_tmp, x_tbl, #16
	ld1b	z_gft1_hi.b, p0/z, [x_tmp]

	/* vector length agnostic */
.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* load src data - use non-temporal hint for streaming data */
	ldnt1b	z_src.b, p0/z, [x_src, x_pos]

	/* split 4-bit lo; 4-bit hi - optimized with SVE2 */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	ushr	z_src_hi.b, z_src.b, #4	/* unsigned shift right */

	/* table indexing - SVE2 improves TBL performance */
	tbl	z_tmp1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp1_hi.b, {z_gft1_hi.b}, z_src_hi.b

	/* exclusive or - could use EOR3 if more terms existed */
	eor	z_dest.d, z_tmp1_hi.d, z_tmp1_lo.d

	/* store dest data - use streaming store if appropriate */
	st1b	z_dest.b, p0, [x_dest, x_pos]
	
	/* increment - optimized for SVE2 */
	incb	x_pos, all, mul #1

	b	.Lloopsve_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret