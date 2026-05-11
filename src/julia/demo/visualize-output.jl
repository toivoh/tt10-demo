module VisualizeOutput
using DelimitedFiles
using ImageView
using ColorTypes

#path = "../../../test/"
path = "../../../../tt10-demo/test/"

#source = "rtl-output-f256-l58-data.txt"
#source = "gl-output-f255-l1050-x0-data.txt"
#source = "rtl-output-f255-l1050-data.txt"
#source = "gl-output-f255-l1050-data.txt"
#source = "rtl-output-f0-l525-data.txt"
#source = "rtl-output-f0-l58-data.txt"
#source = "rtl-output-f1-l525-data.txt"
#source = "gl-output-f1-l525-data.txt"
#source = "gl-output-f1023-l525-data.txt"


#source = "gl-output-f499-l525-data.txt" # music start
#source = "gl-output-f997-l525-data.txt" # title
#source = "gl-output-f1598-l525-data.txt" # twister
#source = "gl-output-f3495-l525-data.txt" # music restart
#source = "gl-output-f4244-l525-data.txt" # spiral, prenoise stop
#source = "gl-output-f4742-l525-data.txt" # title again
#source = "gl-output-f5586-l525-data.txt" # partial title + twister
source = "rtl-output-f5586-l525-data.txt" # partial title + twister
#source = "gl-output-f5867-l525-data.txt" # partial title + spiral
#source = "gl-output-f6491-l525-data.txt" # noise start

data = readdlm(path*source, Int)


r1 = data .& 1
g1 = (data .>> 1) .& 1
b1 = (data .>> 2) .& 1
vsync = (data .>> 3) .& 1
r0 = (data .>> 4) .& 1
g0 = (data .>> 5) .& 1
b0 = (data .>> 6) .& 1
hsync = (data .>> 7) .& 1
audio_out = (data .>> 8) .& 1

r = r0 + 2r1
g = g0 + 2g1
b = b0 + 2b1

rgb = map((r, g, b)->RGB(r/3, g/3, b/3), r, g, b)
#rgb_rot = rgb[:,end:-1:begin]'

c = map((r, g, b)->RGB(r, g, b), audio_out, hsync, vsync)

imshow(rgb)
imshow(c)

end # module
