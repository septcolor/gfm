module gfm.image.image;

import gfm.math.vector;

// An image is a concept


/**
 * Test if I is an Image.
 *
 * A, imùage has at least the following features:
 * $(UL
 * $(LI defines element_t as the type of elements (eg. pixels))
 * $(LI has a dimension of type vec2i)
 * $(LI has getter/setter for individual elements)
 * )
 */
template isImage(I)
{
    enum bool isImage = is(typeof(
    {
        I i;                            // can be defined
        const I ci;
        I.element_t e;                  // defined the type element_t
        vec2i dim = ci.dimension;       // has dimension
        I.element_t f = ci.get(0, 0);   // can get element
        i.set(0, 0, f);                 // can set element
    }()));
}

/// Return true if an image contains the given point.
bool contains(I)(I img, int x, int y) if (isImage!I)
{
    return cast(uint)x < img.dimension.x && cast(uint)x < img.dimension.y;
}

/// Draw a single pixel
void drawPixel(I, P)(I img, int x, int y, P p) if (isImage!I && is(P : I.element_t))
{
    if (!img.contains(x, y))
        return;
    img.set(x, y, p);
}

/// Edge modes define how images are samples beyond their boundaries.
enum EdgeMode
{
    BLACK,
    CLAMP,
    REPEAT,
    ASSERT
}

/// Returns: pixel of an Image at position (x, y). 
/// At boundaries, what happens depends on em.
I.element_t getPixel(I)(I img, int x, int y, EdgeMode em)
{
    if (!img.contains(x, y))
    {
        final switch(em)
        {
            case EdgeMode.BLACK:
                return I.element_t.init;

            case EdgeMode.CLAMP:
            {
                if (x < 0) x = 0;
                if (y < 0) y = 0;
                if (x >= img.dimension.x) x = img.dimension.x - 1;
                if (y >= img.dimension.y) y = img.dimension.y - 1;
                break;
            }

            case EdgeMode.REPEAT:
            {
                x = moduloWrap!int(x, img.dimension.x);
                y = moduloWrap!int(y, img.dimension.y);
                break;
            }

            case EdgeMode.ASSERT: 
                assert(false);
        }
    }
    
    return img.get(x, y);
}


/// Fills an uniform rectangle area in an Image.
void fillRect(I, P)(I img, int x, int y, int width, int height, P e) if (isImage!I && is(P : I.element_t))
{
    for (int j = 0; j < height; ++j)
        for (int i = 0; i < width; ++i)
            img.set(x + i, y + j, e);
}

/// Fill a whole image with a single element value.
void fillImage(I, P)(I img, P e) if (isImage!I && is(P : I.element_t))
{
    immutable int width = img.dimension.x;
    immutable int height = img.dimension.y;
    for (int j = 0; j < height; ++j)
        for (int i = 0; i < width; ++i)
            img.set(i, j, e);
}

/// Performs an image blit from src to dest.
void copyRect(I)(I dest, I src) if (isImage!I)
{
    // check same size
    assert(dest.dimension == src.dimension);

    immutable int width = dest.dimension.x;
    immutable int height = dest.dimension.y;
    for (int j = 0; j < height; ++j)
        for (int i = 0; i < width; ++i)
        {
            auto p = src.get(i, j);
            dest.set(i, j, p);
        }
}

/// Draws an horizontal line on an Image.
void drawHorizontalLine(I, P)(I img, int x1, int x2, int y, P p) if (isImage!I && is(P : I.element_t))
{
    for (int x = x1; x < x2; ++x)
        img.drawPixel(x, y, p);
}

/// Draws a vertical line on an Image.
void drawVerticalLine(I, P)(I img, int x, int y1, int y2, P p) if (isImage!I && is(P : I.element_t))
{
    for (int y = y1; y < y2; ++y)
        img.drawPixel(x, y, p);
}
