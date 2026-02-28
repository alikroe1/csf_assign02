/*
 * x86-64 assembly language implementations of functions
 */

	.section .text

/* Offsets of struct Image fields */
#define IMAGE_WIDTH_OFFSET   0
#define IMAGE_HEIGHT_OFFSET  4
#define IMAGE_DATA_OFFSET    8

/*
 * TODO: define your helper functions here.
 * Don't forget to use the .globl directive to make
 * them visible to the test code.
 */

.globl rowIndex
rowIndex:
	/*
	 * Parameters:
	 *   %edi - index of pixel
	 *   %esi - width of image
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
	*   %rax - get index of pixel
	*
	* Returns:
	*   %rax - pointer to input_img->data[row * input_img->width + col]
 	*/
	movl %esi, %eax
	movl %edx, %ecx
	imull 0(%rdi)
	addl %ecx, %eax
	movq 8(%rdi), %rdx
	movslq %eax, %rax
	movl (%rdx, %rax, 4), %eax
	ret

.globl getRed
getRed:
	movl %edi, %eax
	shrl $24, %eax
	ret

.globl getGreen
getGreen:
	movl %edi, %eax
	shrl $16, %eax
	andl $0xFF, %eax
	ret

.globl getBlue
getBlue:
	movl %edi, %eax
	shrl $8, %eax
	andl $0xFF, %eax
	ret

.globl getAlpha
getAlpha:
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
	 *   %edi - local red
	 *   %esi - local green
	 *   %edx - local blue
	 *   %ecx - local alpha
	 *
	 * Returns:
	 *   %eax - final pixel
	 */
	/* clean bits */
	andl $0xFF, %edi
	andl $0xFF, %esi
	andl $0xFF, %edx
	andl $0xFF, %ecx
	/* shift RGBA values */
	shll $24, %edi
	shll $16, %esi
	shll $8,  %edx
	movl %edi, %eax
	/* add values to make pixel */
	orl  %esi, %eax
	orl  %edx, %eax
	orl  %ecx, %eax
	ret

.globl createAveragePixel
createAveragePixel:
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15

	/* add pixel one values */
	call getRed
	movl %eax, %r12d
	call getGreen
	movl %eax, %r13d
	call getBlue
	movl %eax, %r14d
	call getAlpha
	movl %eax, %r15d

	/* add pixel two values */
	movl %esi, %edi
	call getRed
	addl %eax, %r12d
	call getGreen
	addl %eax, %r13d
	call getBlue
	addl %eax, %r12d
	call getAlpha
	addl %eax, %r15d

	/* divide by 2 */
	shrl $1, %r12d
	shrl $1, %r13d
	shrl $1, %r14d
	shrl $1, %r15d

	/* return createPixel */
	movl %r12d, %edi
	movl %r13d, %esi
	movl %r14d, %edx
	movl %r15d, %ecx
	call createPixel

	popq %r15
	popq %r14
	popq %r13
	popq %r12
	ret

.globl quadAveragePixel
quadAveragePixel:
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15

	/* add pixel one values */
	call getRed
	movl %eax, %r12d
	call getGreen
	movl %eax, %r13d
	call getBlue
	movl %eax, %r14d
	call getAlpha
	movl %eax, %r15d

	/* add pixel two values */
	movl %esi, %edi
	call getRed
	addl %eax, %r12d
	call getGreen
	addl %eax, %r13d
	call getBlue
	addl %eax, %r12d
	call getAlpha
	addl %eax, %r15d

	/* add pixel three values */
	movl %edx, %edi
	call getRed
	addl %eax, %r12d
	call getGreen
	addl %eax, %r13d
	call getBlue
	addl %eax, %r12d
	call getAlpha
	addl %eax, %r15d

	/* add pixel four values */
	movl %ecx, %edi
	call getRed
	addl %eax, %r12d
	call getGreen
	addl %eax, %r13d
	call getBlue
	addl %eax, %r12d
	call getAlpha
	addl %eax, %r15d

	/* divide by 4 */
	shrl $2, %r12d
	shrl $2, %r13d
	shrl $2, %r14d
	shrl $2, %r15d

	/* return createPixel */
	movl %r12d, %edi
	movl %r13d, %esi
	movl %r14d, %edx
	movl %r15d, %ecx
	call createPixel

	popq %r15
	popq %r14
	popq %r13
	popq %r12
	ret


/*
 * Definitions of image transformation functions
 */

/*
 *  Transform the entire image by shrinking it down both 
 *  horizontally and vertically (by potentially different
 *  factors). This is equivalent to sampling the orignal image
 *  for every pixel that is in certain rows and columns as 
 *  specified in the function inputs.
 * 
 *  Take the image below where each letter corresponds to a pixel
 * 
 *                  XAAAYBBB
 *                  AAAABBBB
 *                  ZCCCWDDD
 *                  CCCCDDDD
 * 
 *  If the user specified to shrink it horazontally by a factor 
 *  of 4 and shrink it vertically by a factor of 2, you would 
 *  sample pixel that had a row index such that 
 * 
 *              row index % 2 = 0 
 * 
 *  and a column index such that
 * 
 *              column index % 4 = 0
 * 
 *  in the above example, this would mean pixels that are in 
 *  rows 0 and 2 with columns 0 and 4. 
 *  The resultant image is:
 * 
 *                  XY
 *                  ZW
 *  
 *  @param input_img pointer to the input Image
 *  @param output_img pointer to the output Image (in which the
 *                    transformed pixels should be stored)
 *  @param xfac factor to downsize the image horizontally; guaranteed to be positive
 *  @param yfac factor to downsize the image vertically; guaranteed to be positive
 */
	.globl imgproc_squash
imgproc_squash:

	/*
	* 
 	* Parameters:
	*   %rdi - pointer to input Image
	*   %rsi - pointer to output Image
	*   %edx - x_fac
	*   %ecx - y_fac
	*   
	* Register use:
 	*   %r12 - output pixel row (i)
 	*   %r13 - output pixel column (j)
 	*   %r14d - output image pixel index (out_w * i + j)
 	*   %r15d - input image pixel index (input_image->width * i * y_fac + j * x_fac)
 	*   %rbx - intermediary arithmetic value
	*   %eax - input_img pixel
 	*
 	*/
	
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq %rbx

	movl $0, %r12d # %r12d = int i = 0
	.Louter_for_squash:
		cmpl 4(%rsi), %r12d # compare i ? out_h
		jge .Lend_outer_squash # if i >= h, jump to end_outer
		
		movl $0, %r13d # %r13d = int j = 0
		.Linner_for_squash:
			cmp (%rsi), %r13d # compare j ? out_w
			jge .Lend_inner_squash # if j >= out_w, jump to outer_for

			movl (%rsi), %r14d # %r14d = out_w
			imul %r12d, %r14d # %r14d = out_w * i
			addl %r13d, %r14d # %r14d = out_w * i + j
			
			movl (%rdi), %r15d # %r15d = input_image->width
			imul %r12d, %r15d # %r15d = input_image->width * i
			imul %ecx, %r15d # %r15d = input_image->width * i * y_fac
			movl %r13d, %ebx # %ebx = j
			imul %edx, %ebx # %ebx = j * x_fac
			addl %ebx, %r15d # %r15d = input_image->width * i * y_fac + j * x_fac
			
			movq 8(%rdi), %rbx # store input_img->data
			movl (%rbx,%r15,4), %eax # store input_img->data[src_row * input_img->width + src_col]
			movq 8(%rsi), %r15 # store output_img->data
			movl %eax, (%r15,%r14,4) # replace output_img->data[i * out_w + j]

			addl $1, %r13d # j++
			jmp .Linner_for_squash

			.Lend_inner_squash:
				addl $1, %r12d # i++
				jmp .Louter_for_squash
		
		.Lend_outer_squash:

			popq %rbx
			popq %r15
			popq %r14
			popq %r13
			popq %r12

			ret

/*
 *  Transform the color component values in each input pixel
 *  by applying a rotation on the values of the color components
 *  I.e. the old pixel's red component value will be used for
 *  the new pixel's green component value, the old pixel's green
 *  component value will be used new pixel's blue component value
 *  and the old pixel's blue component value will be used new 
 *  pixel's red component value. The alpha value should not change.
 *  For instance, if a pixel had the hex value 0xAABBCCDD, the 
 *  transformed pixel would become 0xCCAABBDD
 * 
 *  @param input_img pointer to the input Image
 *  @param output_img pointer to the output Image (in which the
 *                    transformed pixels should be stored)
 */
	.globl imgproc_color_rot
imgproc_color_rot:
	/*
	 * Register use:
	 *   %r12d - total number of pixels by height * width
	 *   %r13 - pointer to input image data 
	 *   %r14 - pointer to output image data 
	 *   %r15d - loop index/current pixel
	 *
	 *   %eax - temp variable for current pixel value 
	 *   %r8d - red component 
	 *   %r9d - green component 
	 *   %r10d - blue component 
	 *   %r11d - alpha component 
	 */
	# similarly to our C function, find dimensions of image and iterate and change each pixel shifting colors
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15

	#get pixel height and width and store dimensions to eax
	movl (%rdi), %eax
	imull 4(%rdi), %eax

	#store picture dimensions into r12
	movl %eax, %r12d

	#find the data value and store into r13
	movq 8(%rdi), %r13

	#same for our image and output image 
	movq 8(%rsi), %r14
	

	#set the start of our loop to 0
	movl $0, %r15d

.Lclr_rot_loop:
	#set out loop iterate through every pixel
	cmpl %r12d, %r15d
	jge	.Lclr_rot_loop_done

	#for each pixel, store data (r13 = data of r15 value)
	movl (%r13, %r15, 4), %eax

	#get the rgb + alpha of each pixel
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

	#create new pixel based on the colors and shift accordingly
	shll $24, %r10d
	shll $16, %r8d  
	shll $8, %r9d 

	#now add the shifts to r10d
	orl %r8d, %r10d
	orl %r9d, %r10d
	orl %r11d, %r10d    

	#store this new data to r15, our output
	movl %r10d, (%r14, %r15, 4)   

	#increment for next pixel
	incl %r15d
	jmp .Lclr_rot_loop

.Lclr_rot_loop_done:
	#free memory of our variables
	popq %r15
	popq %r14
	popq %r13
	popq %r12

	ret


/*
 *  Transform the input image using a blur effect.
 * 
 *  Each pixel of the output image should have its color components
 *  determined by taking the average of the color components of pixels
 *  within blur_dist number of pixels horizontally and vertically from
 *  the pixel's location in the original image. For example, if
 *  blur_dist is 0, then only the original pixel is considered, and the
 *  the output image should be identical to the input image. If blur_dist
 *  is 1, then the original pixel and the 8 pixels immediately surrounding
 *  it would be considered, etc.  Pixels positions not within the bounds of
 *  the image should be ignored: i.e., their color components aren't
 *  considered in the computation of the result pixels.
 * 
 *  The alpha value each output pixel should be identical to the
 *  corresponding input pixel.
 * 
 *  Averages should be computed using purely integer arithmetic with
 *  no rounding.
 * 
 *  @param input_img pointer to the input Image
 *  @param output_img pointer to the output Image (in which the
 *                    transformed pixels should be stored)
 *  @param blur_dist all pixels whose x/y coordinates are within
 *                   this many pixels of the x/y coordinates of the
 *                   original pixel should be included in the color
 *                   component averages used to determine the color
 *                   components of the output pixel
 */

	/*
	 *Register use:
	 *%r12 - pointer to input image struct
	 *%r13 - pointer to output image struct
	 *%r14d - blur_dist
	 *%r15d - rows (height)
	 *%ebx - cols (width)
	 *%r8d - i / k
	 *%r9d - j / l
	 *-20(%rbp) - PixelAverager struct
	 *-24(%rbp) - k
	 *-28(%rbp) - l
	 *-32(%rbp) - i
	 *-36(%rbp) - j
	 */
	.globl imgproc_blur
imgproc_blur:
	
	#initalize variables
	pushq %rbp
	movq %rsp, %rbp
	pushq %rbx
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	subq $8, %rsp

	#use our variables for our inputs
	movq %rdi, %r12 #r12 = input_img
	movq %rsi, %r13 #r13 = output_img
	movl %edx, %r14d #r14d = blur_dist

	#x and y of our image
	movl 4(%r12), %r15d
	movl (%r12), %ebx

	#intitalize for loop with i = 0 and j = 0
	movl $0, %r8d                
.Lfor_loop1:
	#until i >= the rows
	cmpl %r15d, %r8d      
	jge .Lblur_done        
	movl $0, %r9d

.Lfor_loop2:
	#until j >= cols
	cmpl %ebx, %r9d
	jge .Lfor_loop1_increment    

	movl $0, %ecx #red
	movl $0, %ebp #green
	movl $0, (%rsp) #blue
	movl $0, 4(%rsp) #total

	#set k = -blur_dist
	movl %r14d, %edi
	negl %edi

.Lfor_loop3:
	#iterate k from -blur_dist to blur_dist
	cmpl %r14d, %edi
	jg .Lfor_loop3_done

	#set l = -blur_dist
	movl %r14d, %esi
	negl %esi

.Lfor_loop4:
	#iterate l from -blur_dist to blur_dist
	cmpl %r14d, %esi
	jg .Lfor_loop3_increment

	#currX = i + k
	movl %r8d, %edx
	addl %edi, %edx

	#border x check
	cmpl $0, %edx
	jl .Lskip_pixel
	cmpl %r15d, %edx
	jge .Lskip_pixel

	#currY = j + l
	movl %r9d, %eax
	addl %esi, %eax

	#border y pixel check
	cmpl $0, %eax
	jl .Lskip_pixel
	cmpl %ebx, %eax
	jge .Lskip_pixel
	
	#get current and get colors
	imull %ebx, %edx
	addl %eax, %edx
	movq 8(%r12), %rax
	movl (%rax,%rdx,4), %edx
	
	#get red and add
	movl %edx, %eax
	shrl $24, %eax
	andl $0xFF, %eax
	addl %eax, %ecx

	#get green and add
	movl %edx, %eax
	shrl $16, %eax
	andl $0xFF, %eax
	addl %eax, %ebp

	#get blue and add
	movl %edx, %eax
	shrl $8, %eax
	andl $0xFF, %eax
	addl %eax, (%rsp)

	#increment total
	incl 4(%rsp)


.Lskip_pixel:
	#increment l
	incl %esi
	jmp .Lfor_loop4
.Lfor_loop3_increment:
	# increment for next row(inner)
	incl %edi
	jmp .Lfor_loop3

.Lfor_loop3_done:
	#get pos = i * cols + j
	movl %r8d, %eax
	imull %ebx, %eax
	addl %r9d, %eax

	#save position to edi
	movl %eax, %edi   

	#get OG alpha from input pixel
	movq 8(%r12), %rax
	movl (%rax,%rdi,4), %eax
	andl $0xFF, %eax

	# esi = alpha
	movl %eax, %esi       

	#load total for division
	movl 4(%rsp), %r10d

	#avg red = red / total
	movl %ecx, %eax
	cdq
	idivl %r10d
	movl %eax, %r11d

	#avg green = green / total
	movl %ebp, %eax
	cdq
	idivl %r10d
	movl %eax, %ecx

	#avg blue = blue / total
	movl (%rsp), %eax
	cdq
	idivl %r10d

	#create new pixel with our new RGB and A
	shll $24, %r11d
	shll $16, %ecx
	shll $8, %eax
	orl %r11d, %ecx
	orl %eax, %ecx
	orl %esi, %ecx

	#store output_img->data[pos]

	#get i * cols + j and store in pos
	movl %r8d, %edx
	imull %ebx, %edx
	addl %r9d, %edx
	movl %ecx, %eax       
	movq 8(%r13), %rcx
	movl %eax, (%rcx,%rdx,4)  

	#increment 
	incl %r9d
	jmp .Lfor_loop2

.Lfor_loop1_increment:
	# increment for next outer row
	incl %r8d
	jmp .Lfor_loop1

	
.Lblur_done:
	#free memory
	addq $8, %rsp
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbx
	popq %rbp
	
	ret

/*
 *  The `expand` transformation doubles the width and height of the image.
 *  
 *  Let's say that there are n rows and m columns of pixels in the
 *  input image, so there are 2n rows and 2m columns in the output
 *  image.  The pixel color and alpha value of the output pixel at row i and column
 *  j should be computed as follows.
 *  
 *  If both i and j are even, then the color and alpha value of the output
 *  pixel are exactly the same as the input pixel at row i/2 and column j/2.
 *  
 *  If i is even but j is odd, then the color components and alpha value
 *  of the output pixel are computed as the average of those in the input pixels
 *  in row i/2 at columns floor(j/2) and floor(j/2) + 1.
 *  
 *  If i is odd and j is even, then the color components and alpha value
 *  of the output pixel are computed as the average of those in the input pixels
 *  in column j/2 at rows floor(i/2) and  floor(i/2) + 1.
 *  
 *  If both i and j are odd then the color components and alpha value
 *  of the output pixel are computed as the average of the input pixels
 *  
 *  1. At row floor(i/2) and column floor(j/2)
 *  2. At row floor(i/2) and column floor(j/2) + 1
 *  3. At row floor(i/2) + 1 and column floor(j/2)
 *  4. At row floor(i/2) + 1 and column floor(j/2) + 1
 *  
 *  Note that in the cases where either i or j is odd, it is not
 *  necessarily the case that either row floor(i/2) + 1 or
 *  column floor(j/2) + 1 are in bounds in the input image.
 *  Only input pixels that are properly in bounds should be incorporated into
 *  the averages used to determine the color components and alpha value
 *  of the output pixel.
 *  
 *  Averages should be computed using purely integer arithmetic with
 *  no rounding.
 * 
 *  @param input_img pointer to the input Image
 *  @param output_img pointer to the output Image (in which the
 *                    transformed pixels should be stored)
 */

.globl imgproc_expand
imgproc_expand:
	/*
	 * Register use:
	 *   %r12 - pointer to input Image
	 *   %r13 - pointer to output Image
	 *   %r14d - output row (i)
	 *   %r15d - output col (j)
	 *   %ebx  - current output pixel value
	 *
	 * Memory use:
	 *   -20(%rbp) - PixelAverager
	 */

	pushq %rbp
	movq  %rsp, %rbp
	subq  $24, %rsp
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	pushq %rbx

	movq %rdi, %rbx # rbx = input_img
	movq %rsi, %r15 # r15 = output_img 

	/* for (int i = 0; i < output_img->width * output_img->height; i++) */
	movl $0, %r12d # r12 = int i = 0

	.Lbegin_expand_loop:
		movl 0(%r15), %r8d
		imull 4(%r15), %r8d # r8d = output_img->width * output_img->height
		cmpl %r8d, %r12d # i ? output_img->width * output_img->height
		jge .Lend_expand_loop

		# int row = rowIndex(i, output_img->width);
		movl %r12d, %edi
		movl 0(%r15), %esi
		call rowIndex
		movl %eax, %r13d # r13d = row

		# int col = columnIndex(i, output_img->width);
		call columnIndex
		movl %eax, %r14d # r14d = col

		# int right_edge = col/2 + 1 >= input_img->width;
		movl %r14d, %r8d
		shrl $1, %r8d
		addl $1, %r8d
		cmpl 0(%rbx), %r8d
		setge -1(%rbp) # -1(%rbp) = right_edge

		# int bottom_edge = row/2 + 1 >= input_img->height;
		movl %r13d, %r8d
		shrl $1, %r8d
		addl $1, %r8d
		cmpl 4(%rbx), %r8d
		setge -2(%rbp) # -2(%rbp) = bottom_edge

		# uint32_t pixel_original = getPixel(input_img, row/2, col/2);
		movq %rbx, %rdi
		movl %r13d, %esi
		shrl $1, %esi
		movl %r14d, %edx
		shrl $1, %edx
		call getPixel
		movl %eax, -8(%rbp) # -8(%rbp) = pixel_original

		/* if (row % 2 == 0) */
		testl $1, %r13d
		jnz .Lodd_row
			/* if (col % 2 == 0) */
			testl $1, %r14d
			jnz .Leven_row_odd_col
				# output_img->data[i] = pixel_original;
				movq 8(%r15), %r8
				movl -8(%rbp), %r9d
				movl %r9d, (%r8, %r12d, 4)
				/* continue; */
				jmp .Lcontinue
			/* if (col % 2 != 0) */
			.Leven_row_odd_col:
				/* if (right_edge) */
				testb $1, -1(%rbp)
				jz .Leven_row_odd_col_not_RE
					# output_img->data[i] = pixel_original;
					movq 8(%r15), %r8
					movl -8(%rbp), %r9d
					movl %r9d, (%r8, %r12d, 4)
					jmp .Lcontinue
				/* if (!right_edge) */
				.Leven_row_odd_col_not_RE:
					# uint32_t pixel_right = getPixel(input_img, row/2, col/2 + 1);
					movq %rbx, %rdi
					movl %r13d, %esi
					shrl $1, %esi
					movl %r14d, %edx
					shrl $1, %edx
					addl $1, %edx
					call getPixel
					movl %eax, -12(%rbp) # -12(%rbp) = pixel_right

					# output_img->data[i] = createAveragePixel(pixel_original, pixel_right);
					movl -8(%rbp), %edi
					movl -12(%rbp), %esi
					call createAveragePixel
					movq 8(%r15), %r8
					movl %eax, (%r8, %r12d, 4)

					/* continue */
					jmp .Lcontinue

		/* if (row % 2 != 0) */
		.Lodd_row:
			/* if (col % 2 == 0) */
			testl $1, %r14d
			jnz .Lodd_row_odd_col
				/* if (bottom_edge) */
				testb $1, -2(%rbp)
				jz .Lodd_row_even_col_not_BE
					# output_img->data[i] = pixel_original;
					movq 8(%r15), %r8
					movl -8(%rbp), %r9d
					movl %r9d, (%r8, %r12d, 4)
					/* continue; */
					jmp .Lcontinue
				
				.Lodd_row_even_col_not_BE:
					# uint32_t pixel_below = getPixel(input_img, row/2 + 1, col/2);
					movq %rbx, %rdi
					movl %r13d, %esi
					shrl $1, %esi
					addl $1, %esi
					movl %r14d, %edx
					shrl $1, %edx
					call getPixel
					movl %eax, -16(%rbp) # -16(%rbp) = pixel_below

					# output_img->data[i] = createAveragePixel(pixel_original, pixel_below);
					movl -8(%rbp), %edi
					movl -16(%rbp), %esi
					call createAveragePixel
					movq 8(%r15), %r8
					movl %eax, (%r8, %r12d, 4)

					/* continue; */
					jmp .Lcontinue

			.Lodd_row_odd_col:
				/* if (!right_edge) */
				testb $1, -1(%rbp)
				jnz .Lodd_row_odd_col_RE
					/* if (!bottom_edge) */
					testb $1, -2(%rbp)
					jnz .Lodd_row_odd_col_not_RE_BE
						# uint32_t pixel_right = getPixel(input_img, row/2, col/2 + 1);
						movq %rbx, %rdi
						movl %r13d, %esi
						shrl $1, %esi
						movl %r14d, %edx
						shrl $1, %edx
						addl $1, %edx
						call getPixel
						movl %eax, -12(%rbp) # -12(%rbp) = pixel_right
						# uint32_t pixel_below = getPixel(input_img, row/2 + 1, col/2);
						movq %rbx, %rdi
						movl %r13d, %esi
						shrl $1, %esi
						addl $1, %esi
						movl %r14d, %edx
						shrl $1, %edx
						call getPixel
						movl %eax, -16(%rbp) # -16(%rbp) = pixel_below
						# uint32_t pixel_diagonal = getPixel(input_img, row/2 + 1, col/2 + 1);
						movq %rbx, %rdi
						movl %r13d, %esi
						shrl $1, %esi
						addl $1, %esi
						movl %r14d, %edx
						shrl $1, %edx
						addl $1, %edx
						call getPixel
						movl %eax, -20(%rbp) # -20(%rbp) = pixel_diagonal
						# output_img->data[i] = quadAveragePixel(pixel_original, pixel_right, pixel_below, pixel_diagonal);
						movl -8(%rbp), %edi
						movl -12(%rbp), %esi
						movl -16(%rbp), %edx
						movl -20(%rbp), %ecx
						call quadAveragePixel
						movq 8(%r15), %r8
						movl %eax, (%r8, %r12d, 4)
						jmp .Lcontinue
					/* else if (!right_edge) */
					.Lodd_row_odd_col_not_RE_BE:
						jmp .Leven_row_odd_col_not_RE
				/* else if (right_edge) */
				.Lodd_row_odd_col_RE:
					/* else if (!bottom_edge) */
					testb $1, -2(%rbp)
					jnz .Lodd_row_odd_col_RE_BE
						jmp .Lodd_row_even_col_not_BE
					.Lodd_row_odd_col_RE_BE:
						/* output_img->data[i] = pixel_original; */
						movq 8(%r15), %r8
						movl -8(%rbp), %r9d
						movl %r9d, (%r8, %r12d, 4)
						/* continue; */
						jmp .Lcontinue

	.Lcontinue:
		incl %r12d
		jmp .Lbegin_expand_loop

	.Lend_expand_loop:
		popq %rbx
		popq %r15
		popq %r14
		popq %r13
		popq %r12
		addq  $24, %rsp
		popq  %rbp
		ret
