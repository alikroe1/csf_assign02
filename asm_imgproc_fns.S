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
	# clean bits
	andl $0xFF, %edi
	andl $0xFF, %esi
	andl $0xFF, %edx
	andl $0xFF, %ecx
	#shift RGBA values
	shll $24, %edi
	shll $16, %esi
	shll $8,  %edx
	movl %edi, %eax
	# add values to make pixel
	orl  %esi, %eax
	orl  %edx, %eax
	orl  %ecx, %eax
	ret

	.globl pa_init
pa_init:
	pushq %rbp
	movq  %rsp, %rbp

	movl $0, (%rdi)      # pa->r = 0
	movl $0, 4(%rdi)     # pa->g = 0
	movl $0, 8(%rdi)     # pa->b = 0
	movl $0, 12(%rdi)    # pa->a = 0
	movl $0, 16(%rdi)    # pa->count = 0

	popq %rbp
	ret


	.globl pa_update
pa_update:
	/*
	 * pa_update - adds a pixel's color components to the PixelAverager
	 *
	 * Parameters:
	 *   %rdi - pointer to PixelAverager
	 *   %esi - pixel value
	 */
	pushq %rbp
	movq  %rsp, %rbp

	movl %esi, %eax
	shrl $24, %eax           # eax = red
	addl %eax, (%rdi)        # pa->r += red

	movl %esi, %eax
	shrl $16, %eax
	andl $0xFF, %eax         # eax = green
	addl %eax, 4(%rdi)       # pa->g += green

	movl %esi, %eax
	shrl $8, %eax
	andl $0xFF, %eax         # eax = blue
	addl %eax, 8(%rdi)       # pa->b += blue

	movl %esi, %eax
	andl $0xFF, %eax         # eax = alpha
	addl %eax, 12(%rdi)      # pa->a += alpha

	incl 16(%rdi)            # pa->count++

	popq %rbp
	ret

	.globl pa_update_from_img
pa_update_from_img:
	/*
	 * Parameters:
	 *   %rdi - pointer to Image
	 *   %esi - row
	 *   %edx - col
	 *   %rcx - pointer to PixelAverager
	 */
	pushq %rbp
	movq  %rsp, %rbp
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15

	movq %rdi, %r12          # r12 = img
	movl %esi, %r13d         # r13d = row
	movl %edx, %r14d         # r14d = col
	movq %rcx, %r15          # r15 = &pa

	cmpl $0, %r13d           # row < 0?
	jl   .Limg_oob
	cmpl 4(%r12), %r13d      # row >= img->height?
	jge  .Limg_oob
	cmpl $0, %r14d           # col < 0?
	jl   .Limg_oob
	cmpl (%r12), %r14d       # col >= img->width?
	jge  .Limg_oob

	movl (%r12), %eax        # eax = img->width
	imull %eax, %r13d        # r13d = row * width
	addl %r14d, %r13d        # r13d = row * width + col
	movq 8(%r12), %rax       # rax = img->data
	movl (%rax, %r13, 4), %esi  # esi = data[row*width+col]

	movq %r15, %rdi
	call pa_update

.Limg_oob:                   # out of bounds, do nothing
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbp
	ret

	.globl pa_avg_pixel
pa_avg_pixel:
	/*
	 * Parameters:
	 *   %rdi - pointer to PixelAverager
	 *
	 * Returns:
	 *   averaged pixel in %eax
	 */
	pushq %rbp
	movq  %rsp, %rbp
	pushq %r12

	movq %rdi, %r12          # r12 = &pa

	movl 16(%r12), %ecx      # ecx = pa->count

	movl (%r12), %eax
	xorl %edx, %edx
	divl %ecx                # eax = pa->r / pa->count
	movl %eax, %r8d          # r8d = avg red

	movl 4(%r12), %eax
	xorl %edx, %edx
	divl %ecx                # eax = pa->g / pa->count
	movl %eax, %r9d          # r9d = avg green

	movl 8(%r12), %eax
	xorl %edx, %edx
	divl %ecx                # eax = pa->b / pa->count
	movl %eax, %r10d         # r10d = avg blue

	movl 12(%r12), %eax
	xorl %edx, %edx
	divl %ecx                # eax = pa->a / pa->count
	movl %eax, %r11d         # r11d = avg alpha

	movl %r8d, %edi
	movl %r9d, %esi
	movl %r10d, %edx
	movl %r11d, %ecx
	call createPixel         # eax = final averaged pixel

	popq %r12
	popq %rbp
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

	movq %rdi, %r12          # r12 = input_img
	movq %rsi, %r13          # r13 = output_img

	movl $0, %r14d           # r14d = i = 0

.Lrow_loop:
	movl 4(%r13), %eax       # eax = output_img->height
	cmpl %eax, %r14d         # i ? output height
	jge  .Lall_done

	movl $0, %r15d           # r15d = j = 0

.Lcol_loop:
	movl (%r13), %eax        # eax = output_img->width
	cmpl %eax, %r15d         # j ? output width
	jge  .Lnext_row

	leaq -20(%rbp), %rdi     # store pa struct in memory
	call pa_init

	movl %r14d, %eax
	andl $1, %eax            # eax = i % 2
	movl %r15d, %ecx
	andl $1, %ecx            # ecx = j % 2

	movl %r14d, %r8d
	sarl $1, %r8d            # r8d = i/2
	movl %r15d, %r9d
	sarl $1, %r9d            # r9d = j/2

	# add top_left pixel
	movq %r12, %rdi
	movl %r8d, %esi
	movl %r9d, %edx
	leaq -20(%rbp), %rcx
	call pa_update_from_img

	# handle odd column
	movl %r15d, %ecx
	andl $1, %ecx            # ecx = j % 2
	cmpl $0, %ecx
	je .Lcheck_odd_row

	movl %r14d, %r8d
	sarl $1, %r8d            # r8d = i/2
	movl %r15d, %r9d
	sarl $1, %r9d            # r9d = j/2

	movq %r12, %rdi
	movl %r8d, %esi
	movl %r9d, %edx
	addl $1, %edx 
	leaq -20(%rbp), %rcx
	call pa_update_from_img

.Lcheck_odd_row:
	movl %r14d, %eax
	andl $1, %eax            # eax = i % 2
	movl %r15d, %ecx
	andl $1, %ecx            # ecx = j % 2

	# handle odd row
	cmpl $0, %eax
	je   .Lstore_result

	movl %r14d, %r8d
	sarl $1, %r8d            # r8d = i/2
	movl %r15d, %r9d
	sarl $1, %r9d            # r9d = j/2

	movq %r12, %rdi
	movl %r8d, %esi
	addl $1, %esi
	movl %r9d, %edx
	leaq -20(%rbp), %rcx
	call pa_update_from_img

	cmpl $0, %ecx            # j % 2 ? 0
	je .Lstore_result

	movl %r14d, %r8d
	sarl $1, %r8d            # r8d = i/2
	movl %r15d, %r9d
	sarl $1, %r9d            # r9d = j/2

	movq %r12, %rdi
	movl %r8d, %esi
	addl $1, %esi
	movl %r9d, %edx
	addl $1, %edx
	leaq -20(%rbp), %rcx
	call pa_update_from_img

.Lstore_result:
	leaq -20(%rbp), %rdi
	call pa_avg_pixel
	movl %eax, %ebx

	movl (%r13), %eax
	movl %r14d, %ecx
	imull %eax, %ecx 
	addl %r15d, %ecx

	movq 8(%r13), %rax       # rax = output_img->data
	movl %ebx, (%rax, %rcx, 4) # data[i*width+j] = result pixel

	incl %r15d               # j++
	jmp  .Lcol_loop

.Lnext_row:
	incl %r14d               # i++
	jmp  .Lrow_loop

.Lall_done:
	popq %rbx
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	addq $24, %rsp
	popq %rbp
	ret