package game

import image "core:image"
import bmp "core:image/bmp"
import jpeg "core:image/jpeg"
import png "core:image/png"
import qoi "core:image/qoi"
import tga "core:image/tga"

IMAGE_FILE_FORMAT_LABEL :: "PNG, JPEG, BMP, TGA, QOI"
IMAGE_FILE_FILTER_PATTERN :: "png;jpg;jpeg;bmp;tga;qoi"

shared_image_load_rgba8 :: proc(path: string) -> (img: ^image.Image, ok: bool) {
	options := image.Options{.alpha_add_if_missing}
	#partial switch image.which_file(path) {
	case .PNG:
		img, err := png.load(path, options)
		return shared_image_finish_load(img, err == nil)
	case .JPEG:
		img, err := jpeg.load(path, options)
		return shared_image_finish_load(img, err == nil)
	case .BMP:
		img, err := bmp.load(path, options)
		return shared_image_finish_load(img, err == nil)
	case .TGA:
		img, err := tga.load(path, options)
		return shared_image_finish_load(img, err == nil)
	case .QOI:
		img, err := qoi.load(path, options)
		return shared_image_finish_load(img, err == nil)
	case:
		return nil, false
	}
}

shared_image_finish_load :: proc(img: ^image.Image, decoded: bool) -> (out: ^image.Image, ok: bool) {
	if decoded && shared_image_is_rgba8(img) {
		return img, true
	}
	if img != nil {
		shared_image_destroy(img)
	}
	return nil, false
}

shared_image_is_rgba8 :: proc(img: ^image.Image) -> bool {
	return img != nil && img.depth == 8 && img.channels == 4 && img.width > 0 && img.height > 0
}

shared_image_destroy :: proc(img: ^image.Image) {
	image.destroy(img)
}
