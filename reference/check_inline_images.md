# Check inline images against the HTML that references them (internal)

Each name must be a usable Content-ID token and each path must exist. A
`cid:` in the HTML with no matching image is an error, because the
reader would see a broken image; an image the HTML never references is a
warning.

## Usage

``` r
check_inline_images(inline_images, html)
```

## Arguments

- inline_images:

  Named character vector, name = Content-ID, value = path.

- html:

  The HTML body.

## Value

`NULL`, invisibly. Called for its errors and warnings.
