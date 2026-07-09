package game

import image "core:image"
import bmp "core:image/bmp"
import "core:fmt"
import jpeg "core:image/jpeg"
import "core:os"
import png "core:image/png"
import qoi "core:image/qoi"
import tga "core:image/tga"

IMAGE_FILE_FORMAT_LABEL :: "PNG, JPEG, BMP, TGA, QOI"
IMAGE_FILE_FILTER_PATTERN :: "png;jpg;jpeg;bmp;tga;qoi"

shared_image_load_rgba8 :: proc(path: string) -> (img: ^image.Image, ok: bool) {
	loaded_img, reason := shared_image_load_rgba8_diagnostic(path)
	_ = reason
	return loaded_img, loaded_img != nil
}

shared_image_load_rgba8_diagnostic :: proc(path: string) -> (img: ^image.Image, reason: string) {
	if len(path) == 0 {
		return nil, "empty path"
	}
	if !os.exists(path) {
		return nil, "file does not exist"
	}
	if !os.is_file(path) {
		return nil, "path is not a regular file"
	}

	options := image.Options{.alpha_add_if_missing}
	kind := image.which_file(path)
	#partial switch kind {
	case .PNG:
		img, err := png.load(path, options)
		return shared_image_finish_load_diagnostic(img, err, "PNG")
	case .JPEG:
		img, err := jpeg.load(path, options)
		return shared_image_finish_load_diagnostic(img, err, "JPEG")
	case .BMP:
		img, err := bmp.load(path, options)
		return shared_image_finish_load_diagnostic(img, err, "BMP")
	case .TGA:
		img, err := tga.load(path, options)
		return shared_image_finish_load_diagnostic(img, err, "TGA")
	case .QOI:
		img, err := qoi.load(path, options)
		return shared_image_finish_load_diagnostic(img, err, "QOI")
	case:
		if kind == .Unknown {
			return nil, fmt.tprintf("unknown image file type; supported formats: %s", IMAGE_FILE_FORMAT_LABEL)
		}
		return nil, fmt.tprintf("unsupported image file type %v; supported formats: %s", kind, IMAGE_FILE_FORMAT_LABEL)
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

shared_image_finish_load_diagnostic :: proc(img: ^image.Image, err: image.Error, format: string) -> (out: ^image.Image, reason: string) {
	if err != nil {
		if img != nil {
			shared_image_destroy(img)
		}
		return nil, fmt.tprintf("%s decoder failed: %v", format, err)
	}
	if shared_image_is_rgba8(img) {
		return img, ""
	}
	if img == nil {
		return nil, fmt.tprintf("%s decoder did not return image data", format)
	}

	width := img.width
	height := img.height
	channels := img.channels
	depth := img.depth
	shared_image_destroy(img)
	return nil, fmt.tprintf("%s decoded to width=%d height=%d channels=%d depth=%d; expected non-empty 8-bit RGBA image data", format, width, height, channels, depth)
}

shared_image_is_rgba8 :: proc(img: ^image.Image) -> bool {
	return img != nil && img.depth == 8 && img.channels == 4 && img.width > 0 && img.height > 0
}

shared_image_destroy :: proc(img: ^image.Image) {
	image.destroy(img)
}
