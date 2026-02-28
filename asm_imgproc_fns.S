/*
 * x86-64 assembly language implementations of functions
 */

	.section .text

/* Offsets of struct Image fields */
#define IMAGE_WIDTH_OFFSET   0
#define IMAGE_HEIGHT_OFFSET  4
#define IMAGE_DATA_OFFSET    8

.globl rowIndex
rowIndex:
	/*
	 * Parameters:
	 *   %edi - index of pixel
	 *   %esi - width of image
	 *
	 * Register use:
	 *   %eax - dividend (index), then quotient (index / width)
	 *   %edx - remainder (cleared before division)
	 *
	 * Returns:
	 *   %eax - row index (index / width)
 	*/
	movl %edi, %eax
	xorl  %edx, %edx
	divl %esi
	ret

.globl columnIndex
columnIndex:
	/*
	 * Parameters:
	 *   %edi - index of pixel
	 *   %esi - width of image
	 *
	 * Register use:
	 *   %eax - dividend (index), then quotient
	 *   %edx - remainder (index % width), then moved to return value
	 *
	 * Returns:
	 *   %eax - column index (index % width)
	 */
	movl %edi, %eax
	xorl  %edx, %edx
	divl %esi
	movl %edx, %eax
	ret

.globl getPixel
getPixel:
	/*
 	* Parameters:
	*   %rdi - pointer to input_img
	*   %esi - row index
	*   %edx - column index
	*
	* Register use:
	*   %eax - row * input_img->width, then + col to form flat index
	*   %ecx - saved col (one-operand imull clobbers %edx) #CHANGED
	*   %rdx - reused as pointer to input_img->data after index is computed
	*   %rax - sign-extended flat index for 64-bit addressing #CHANGED
	*
	* Returns:
	*   %eax - input_img->data[row * input_img->width + col]
 	*/
	movl %esi, %eax
	movl %edx, %ecx     #CHANGED - save col before imull clobbers %edx
	imull 0(%rdi)
	addl %ecx, %eax     #CHANGED - add saved col
	movq 8(%rdi), %rdx
	movslq %eax, %rax   #CHANGED - sign-extend to 64-bit for addressing
	movl (%rdx, %rax, 4), %eax #CHANGED
	ret

.globl getRed
getRed:
	/*
	 * Parameters:
	 *   %edi - pixel value
	 *
	 * Register use:
	 *   %eax - pixel value, shifted right 24 to isolate red byte
	 *
	 * Returns:
	 *   %eax - red component
	 */
	movl %edi, %eax
	shrl $24, %eax
	ret

.globl getGreen
getGreen:
	/*
	 * Parameters:
	 *   %edi - pixel value
	 *
	 * Register use:
	 *   %eax - pixel value, shifted right 16 and masked to isolate green byte
	 *
	 * Returns:
	 *   %eax - green component
	 */
	movl %edi, %eax
	shrl $16, %eax
	andl $0xFF, %eax
	ret

.globl getBlue
getBlue:
	/*
	 * Parameters:
	 *   %edi - pixel value
	 *
	 * Register use:
	 *   %eax - pixel value, shifted right 8 and masked to isolate blue byte
	 *
	 * Returns:
	 *   %eax - blue component
	 */
	movl %edi, %eax
	shrl $8, %eax
	andl $0xFF, %eax
	ret

.globl getAlpha
getAlpha:
	/*
	 * Parameters:
	 *   %edi - pixel value
	 *
	 * Register use:
	 *   %eax - pixel value masked to isolate alpha byte
	 *
	 * Returns:
	 *   %eax - alpha component
	 */
	movl %edi, %eax
	andl $0xFF, %eax
	ret

.globl createPixel
createPixel:
	/*
	 * Parameters:
	 *   %edi - red
	 *   %esi - green
	 *   %edx - blue
	 *   %ecx - alpha
	 *
	 * Register use:
	 *   %edi - red, masked then shifted to bits 31-24
	 *   %esi - green, masked then shifted to bits 23-16
	 *   %edx - blue, masked then shifted to bits 15-8
	 *   %ecx - alpha, masked, placed in bits 7-0
	 *   %eax - accumulates OR of all four shifted components
	 *
	 * Returns:
	 *   %eax - packed RGBA pixel
	 */
	andl $0xFF, %edi
	andl $0xFF, %esi
	andl $0xFF, %edx
	andl $0xFF, %ecx
	shll $24, %edi
	shll $16, %esi
	shll $8,  %edx
	movl %edi, %eax
	orl  %esi, %eax
	orl  %edx, %eax
	orl  %ecx, %eax
	ret

.globl createAveragePixel
createAveragePixel:
	/*
	 * Parameters:
	 *   %edi - pixel 1
	 *   %esi - pixel 2
	 *
	 * Register use:
	 *   %r12d - pixel 1 (local copy)
	 *   %r13d - pixel 2 (local copy)
	 *   %r14d - avg_red
	 *   %r15d - avg_green
	 *   %ebx  - avg_blue
	 *   %eax  - intermediate
	 *   %ecx  - intermediate
	 *
	 * Returns:
	 *   %eax - average pixel (via createPixel)
	 */
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq %rbx

	movl %edi, %r12d
	movl %esi, %r13d

	#avg_red
	movl %r12d, %edi
	call getRed
	movl %eax, %ecx
	movl %r13d, %edi
	call getRed
	addl %ecx, %eax
	shrl $1, %eax
	movl %eax, %r14d

	#avg_green
	movl %r12d, %edi
	call getGreen
	movl %eax, %ecx
	movl %r13d, %edi
	call getGreen
	addl %ecx, %eax
	shrl $1, %eax
	movl %eax, %r15d

	#avg_blue
	movl %r12d, %edi
	call getBlue
	movl %eax, %ecx
	movl %r13d, %edi
	call getBlue
	addl %ecx, %eax
	shrl $1, %eax
	movl %eax, %ebx

	#avg_alpha
	movl %r12d, %edi
	call getAlpha
	movl %eax, %ecx
	movl %r13d, %edi
	call getAlpha
	addl %ecx, %eax
	shrl $1, %eax

	#createPixel(avg_red, avg_green, avg_blue, avg_alpha)
	movl %r14d, %edi
	movl %r15d, %esi
	movl %ebx, %edx
	movl %eax, %ecx
	call createPixel

	popq %rbx
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	ret

.globl quadAveragePixel
quadAveragePixel:
	/*
	 * Parameters:
	 *   %edi - pixel 1
	 *   %esi - pixel 2
	 *   %edx - pixel 3
	 *   %ecx - pixel 4
	 *
	 * Register use:
	 *   %r12d - pixel 1 (local copy)
	 *   %r13d - pixel 2 (local copy)
	 *   %r14d - pixel 3 (local copy)
	 *   %r15d - pixel 4 (local copy)
	 *   %ebx  - avg_blue
	 *   %eax  - intermediate
	 *   %ecx  - pixel sum, then avg_alpha (passed to createPixel)
	 *   -8(%rbp)  - avg_red
	 *   -12(%rbp) - avg_green
	 *
	 * Returns:
	 *   %eax - average pixel (via createPixel)
	 */
	pushq %rbp
	movq  %rsp, %rbp
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq %rbx
	subq  $8, %rsp

	movl %edi, %r12d
	movl %esi, %r13d
	movl %edx, %r14d
	movl %ecx, %r15d

	# avg_red
	movl %r12d, %edi
	call getRed
	movl %eax, %ecx
	movl %r13d, %edi
	call getRed
	addl %eax, %ecx
	movl %r14d, %edi
	call getRed
	addl %eax, %ecx
	movl %r15d, %edi
	call getRed
	addl %eax, %ecx
	shrl $2, %ecx
	movl %ecx, -8(%rbp)

	# avg_green
	movl %r12d, %edi
	call getGreen
	movl %eax, %ecx
	movl %r13d, %edi
	call getGreen
	addl %eax, %ecx
	movl %r14d, %edi
	call getGreen
	addl %eax, %ecx
	movl %r15d, %edi
	call getGreen
	addl %eax, %ecx
	shrl $2, %ecx
	movl %ecx, -12(%rbp)

	# avg_blue
	movl %r12d, %edi
	call getBlue
	movl %eax, %ecx
	movl %r13d, %edi
	call getBlue
	addl %eax, %ecx
	movl %r14d, %edi
	call getBlue
	addl %eax, %ecx
	movl %r15d, %edi
	call getBlue
	addl %eax, %ecx
	shrl $2, %ecx
	movl %ecx, %ebx

	# avg_alpha
	movl %r12d, %edi
	call getAlpha
	movl %eax, %ecx
	movl %r13d, %edi
	call getAlpha
	addl %eax, %ecx
	movl %r14d, %edi
	call getAlpha
	addl %eax, %ecx
	movl %r15d, %edi
	call getAlpha
	addl %eax, %ecx
	shrl $2, %ecx

	# createPixel(avg_red, avg_green, avg_blue, avg_alpha)
	# %ecx already holds avg_alpha
	movl -8(%rbp), %edi
	movl -12(%rbp), %esi
	movl %ebx, %edx
	call createPixel

	addq  $8, %rsp
	popq %rbx
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbp
	ret

/*
 * Definitions of image transformation functions
 */

	.globl imgproc_squash
imgproc_squash:
	/*
	 * Parameters:
	 *   %rdi - pointer to input Image
	 *   %rsi - pointer to output Image
	 *   %edx - x_fac
	 *   %ecx - y_fac
	 *
	 * Register use:
	 *   %r12d - output pixel row (i)
	 *   %r13d - output pixel column (j)
	 *   %r14d - output image pixel index (out_w * i + j)
	 *   %r15d - input image pixel index (input_image->width * i * y_fac + j * x_fac)
	 *   %ebx  - intermediary arithmetic value (j * x_fac), then reused as data pointer
	 *   %eax  - pixel value loaded from input_img->data
	 */
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq %rbx

	movl $0, %r12d
	.Louter_for_squash:
		cmpl 4(%rsi), %r12d
		jge .Lend_outer_squash

		movl $0, %r13d
		.Linner_for_squash:
			cmp (%rsi), %r13d
			jge .Lend_inner_squash

			movl (%rsi), %r14d
			imul %r12d, %r14d
			addl %r13d, %r14d

			movl (%rdi), %r15d
			imul %r12d, %r15d
			imul %ecx, %r15d
			movl %r13d, %ebx
			imul %edx, %ebx
			addl %ebx, %r15d

			movq 8(%rdi), %rbx
			movl (%rbx,%r15,4), %eax
			movq 8(%rsi), %r15
			movl %eax, (%r15,%r14,4)

			addl $1, %r13d
			jmp .Linner_for_squash

		.Lend_inner_squash:
			addl $1, %r12d
			jmp .Louter_for_squash

	.Lend_outer_squash:
		popq %rbx
		popq %r15
		popq %r14
		popq %r13
		popq %r12
		ret

	.globl imgproc_color_rot
imgproc_color_rot:
	/*
	 * Parameters:
	 *   %rdi - pointer to input Image
	 *   %rsi - pointer to output Image
	 *
	 * Register use:
	 *   %r12d - total number of pixels (width * height)
	 *   %r13  - pointer to input image data array
	 *   %r14  - pointer to output image data array
	 *   %r15d - loop index / current pixel index
	 *   %eax  - current pixel value
	 *   %r8d  - red component (bits 31-24 of original pixel)
	 *   %r9d  - green component (bits 23-16 of original pixel)
	 *   %r10d - blue component (bits 15-8 of original pixel)
	 *   %r11d - alpha component (bits 7-0 of original pixel)
	 */
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15

	movl (%rdi), %eax
	imull 4(%rdi), %eax
	movl %eax, %r12d

	movq 8(%rdi), %r13
	movq 8(%rsi), %r14
	movl $0, %r15d

.Lclr_rot_loop:
	cmpl %r12d, %r15d
	jge .Lclr_rot_loop_done

	movl (%r13, %r15, 4), %eax

	movl %eax, %r8d
	shrl $24, %r8d

	movl %eax, %r9d
	shrl $16, %r9d
	andl $0xFF, %r9d

	movl %eax, %r10d
	shrl $8, %r10d
	andl $0xFF, %r10d

	movl %eax, %r11d
	andl $0xFF, %r11d

	shll $24, %r10d
	shll $16, %r8d
	shll $8, %r9d

	orl %r8d, %r10d
	orl %r9d, %r10d
	orl %r11d, %r10d

	movl %r10d, (%r14, %r15, 4)

	incl %r15d
	jmp .Lclr_rot_loop

.Lclr_rot_loop_done:
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	ret

	.globl imgproc_blur
imgproc_blur:
	/*
	 * Parameters:
	 *   %rdi - pointer to input Image
	 *   %rsi - pointer to output Image
	 *   %edx - blur_dist
	 *
	 * Register use:
	 *   %r12  - pointer to input image struct
	 *   %r13  - pointer to output image struct
	 *   %r14d - blur_dist
	 *   %r15d - rows (height)
	 *   %ebx  - cols (width)
	 *   %r8d  - i (outer row index)
	 *   %r9d  - j (outer col index)
	 *   %ecx  - red accumulator
	 *   8(%rsp)  - green accumulator
	 *   (%rsp)  - blue accumulator
	 *   4(%rsp) - total pixel count
	 *   %edi  - k (row blur offset)
	 *   %esi  - l (col blur offset)
	 *   %edx  - currX = i+k, then flat pixel index
	 *   %eax  - currY = j+l, then pixel data
	 *   %r10d - total (divisor)
	 *   %r11d - avg_red
	 */
	pushq %rbp
	movq %rsp, %rbp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	subq $16, %rsp

	movq %rdi, %r12
	movq %rsi, %r13
	movl %edx, %r14d

	movl 4(%r12), %r15d
	movl (%r12), %ebx

	movl $0, %r8d
.Lfor_loop1:
	cmpl %r15d, %r8d
	jge .Lblur_done
	movl $0, %r9d

.Lfor_loop2:
	cmpl %ebx, %r9d
	jge .Lfor_loop1_increment

	movl $0, %ecx
	movl $0, 8(%rsp)
	movl $0, (%rsp)
	movl $0, 4(%rsp)

	movl %r14d, %edi
	negl %edi

.Lfor_loop3:
	cmpl %r14d, %edi
	jg .Lfor_loop3_done

	movl %r14d, %esi
	negl %esi

.Lfor_loop4:
	cmpl %r14d, %esi
	jg .Lfor_loop3_increment

	movl %r8d, %edx
	addl %edi, %edx

	cmpl $0, %edx
	jl .Lskip_pixel
	cmpl %r15d, %edx
	jge .Lskip_pixel

	movl %r9d, %eax
	addl %esi, %eax

	cmpl $0, %eax
	jl .Lskip_pixel
	cmpl %ebx, %eax
	jge .Lskip_pixel

	imull %ebx, %edx
	addl %eax, %edx
	movq 8(%r12), %rax
	movl (%rax,%rdx,4), %edx

	movl %edx, %eax
	shrl $24, %eax
	andl $0xFF, %eax
	addl %eax, %ecx

	movl %edx, %eax
	shrl $16, %eax
	andl $0xFF, %eax
	addl %eax, 8(%rsp)

	movl %edx, %eax
	shrl $8, %eax
	andl $0xFF, %eax
	addl %eax, (%rsp)

	incl 4(%rsp)

.Lskip_pixel:
	incl %esi
	jmp .Lfor_loop4

.Lfor_loop3_increment:
	incl %edi
	jmp .Lfor_loop3

.Lfor_loop3_done:
	movl %r8d, %eax
	imull %ebx, %eax
	addl %r9d, %eax
	movl %eax, %edi

	movq 8(%r12), %rax
	movl (%rax,%rdi,4), %eax
	andl $0xFF, %eax
	movl %eax, %esi

	movl 4(%rsp), %r10d

	movl %ecx, %eax
	cdq
	idivl %r10d
	movl %eax, %r11d

	movl 8(%rsp), %eax
	cdq
	idivl %r10d
	movl %eax, %ecx

	movl (%rsp), %eax
	cdq
	idivl %r10d

	shll $24, %r11d
	shll $16, %ecx
	shll $8, %eax
	orl %r11d, %ecx
	orl %eax, %ecx
	orl %esi, %ecx

	movl %r8d, %edx
	imull %ebx, %edx
	addl %r9d, %edx
	movl %ecx, %eax
	movq 8(%r13), %rcx
	movl %eax, (%rcx,%rdx,4)

	incl %r9d
	jmp .Lfor_loop2

.Lfor_loop1_increment:
	incl %r8d
	jmp .Lfor_loop1

.Lblur_done:
	addq $16, %rsp
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	popq %rbp
	ret

	.globl imgproc_expand
imgproc_expand:
	/*
	 * Parameters:
	 *   %rdi - pointer to input_img
	 *   %rsi - pointer to output_img
	 *
	 * Register use:
	 *   %r12  - pointer to input_img (local copy)
	 *   %r13  - pointer to output_img (local copy)
	 *   %r14d - output_img->width * output_img->height
	 *   %r15d - iterator (i)
	 *   %ebx  - row of current output pixel
	 *   %r8d  - pixel_original
	 *   %r9d  - right_edge flag
	 *   %r10d - bottom_edge flag
	 *   %r11d - pixel_right (odd-odd case)
	 *   %eax  - scratch / return value
	 *   %ecx  - scratch for parity checks
	 *   %edx  - scratch for getPixel args and address computation
	 *
	 * Memory:
	 *   (%rsp)  - col
	 *   8(%rsp) - pixel_below (odd-odd case) #CHANGED
	 */
	pushq %rbp
	movq  %rsp, %rbp
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq %rbx
	subq  $16, %rsp #CHANGED

	movq %rdi, %r12
	movq %rsi, %r13

	movl (%r13), %eax
	imull 4(%r13), %eax
	movl %eax, %r14d

	movl $0, %r15d

	.Lloop_expand:
		cmpl %r14d, %r15d
		jge .Lloop_expand_done

		movl %r15d, %edi
		movl (%r13), %esi
		call rowIndex
		movl %eax, %ebx

		movl %r15d, %edi
		movl (%r13), %esi
		call columnIndex
		movl %eax, (%rsp)

		movl (%rsp), %edx
		sarl $1, %edx
		addl $1, %edx
		cmpl (%r12), %edx
		setge %r9b
		movzbl %r9b, %r9d

		movl %ebx, %edx
		sarl $1, %edx
		addl $1, %edx
		cmpl 4(%r12), %edx
		setge %r10b
		movzbl %r10b, %r10d

		movq %r12, %rdi
		movl %ebx, %esi
		sarl $1, %esi
		movl (%rsp), %edx
		sarl $1, %edx
		call getPixel
		movl %eax, %r8d

		movl %ebx, %eax
		andl $1, %eax
		cmpl $0, %eax
		jne .Lexpand_odd_row

		movl (%rsp), %ecx
		andl $1, %ecx
		cmpl $0, %ecx
		jne .Lexpand_even_row_odd_col

		# even row, even col
		movq 8(%r13), %rdx
		movl %r8d, (%rdx, %r15, 4)
		jmp .Lcontinue

	.Lexpand_even_row_odd_col:
		cmpl $0, %r9d
		jne .Lexpand_use_original

		# pixel_right = getPixel(input_img, row/2, col/2 + 1)
		movq %r12, %rdi
		movl %ebx, %esi
		sarl $1, %esi
		movl (%rsp), %edx
		sarl $1, %edx
		addl $1, %edx
		call getPixel
		movl %r8d, %edi
		movl %eax, %esi
		call createAveragePixel
		movq 8(%r13), %rdx
		movl %eax, (%rdx, %r15, 4)
		jmp .Lcontinue

	.Lexpand_odd_row:
		movl (%rsp), %ecx
		andl $1, %ecx
		cmpl $0, %ecx
		jne .Lexpand_odd_odd

		cmpl $0, %r10d
		jne .Lexpand_use_original

		# pixel_below = getPixel(input_img, row/2 + 1, col/2)
		movq %r12, %rdi
		movl %ebx, %esi
		sarl $1, %esi
		addl $1, %esi
		movl (%rsp), %edx
		sarl $1, %edx
		call getPixel
		movl %r8d, %edi
		movl %eax, %esi
		call createAveragePixel
		movq 8(%r13), %rdx
		movl %eax, (%rdx, %r15, 4)
		jmp .Lcontinue

	.Lexpand_odd_odd:
		cmpl $0, %r9d
		jne .Lexpand_odd_odd_right_edge

		cmpl $0, %r10d
		jne .Lexpand_odd_odd_bottom_edge

		# pixel_right = getPixel(input_img, row/2, col/2 + 1)
		movq %r12, %rdi
		movl %ebx, %esi
		sarl $1, %esi
		movl (%rsp), %edx
		sarl $1, %edx
		addl $1, %edx
		call getPixel
		movl %eax, %r11d

		# pixel_below = getPixel(input_img, row/2 + 1, col/2)
		movq %r12, %rdi
		movl %ebx, %esi
		sarl $1, %esi
		addl $1, %esi
		movl (%rsp), %edx
		sarl $1, %edx
		call getPixel
		movl %eax, 8(%rsp) #CHANGED - spill pixel_below; avoids clobbering row in %ebx

		# pixel_diagonal = getPixel(input_img, row/2 + 1, col/2 + 1)
		movq %r12, %rdi
		movl %ebx, %esi
		sarl $1, %esi
		addl $1, %esi
		movl (%rsp), %edx
		sarl $1, %edx
		addl $1, %edx
		call getPixel

		movl %r8d, %edi
		movl %r11d, %esi
		movl 8(%rsp), %edx #CHANGED - load pixel_below from stack
		movl %eax, %ecx
		call quadAveragePixel
		movq 8(%r13), %rdx
		movl %eax, (%rdx, %r15, 4)
		jmp .Lcontinue

	.Lexpand_odd_odd_right_edge:
		cmpl $0, %r10d
		jne .Lexpand_use_original

		# pixel_below = getPixel(input_img, row/2 + 1, col/2)
		movq %r12, %rdi
		movl %ebx, %esi
		sarl $1, %esi
		addl $1, %esi
		movl (%rsp), %edx
		sarl $1, %edx
		call getPixel
		movl %r8d, %edi
		movl %eax, %esi
		call createAveragePixel
		movq 8(%r13), %rdx
		movl %eax, (%rdx, %r15, 4)
		jmp .Lcontinue

	.Lexpand_odd_odd_bottom_edge:
		# pixel_right = getPixel(input_img, row/2, col/2 + 1)
		movq %r12, %rdi
		movl %ebx, %esi
		sarl $1, %esi
		movl (%rsp), %edx
		sarl $1, %edx
		addl $1, %edx
		call getPixel
		movl %r8d, %edi
		movl %eax, %esi
		call createAveragePixel
		movq 8(%r13), %rdx
		movl %eax, (%rdx, %r15, 4)
		jmp .Lcontinue

	.Lexpand_use_original:
		movq 8(%r13), %rdx
		movl %r8d, (%rdx, %r15, 4)

	.Lcontinue:
		incl %r15d
		jmp .Lloop_expand

.Lloop_expand_done:
	addq  $16, %rsp #CHANGED
	popq  %rbx
	popq  %r15
	popq  %r14
	popq  %r13
	popq  %r12
	popq  %rbp
	ret

/*
vim:ft=gas:
*/