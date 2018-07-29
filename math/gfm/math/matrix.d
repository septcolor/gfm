/// Custom sized 2-dimension Matrices
module gfm.math.matrix;

import std.math,
       std.typetuple,
       std.traits,
       std.string,
       std.typecons,
       std.conv;

import gfm.math.vector,
       gfm.math.shapes,
       gfm.math.quaternion;

/// Generic non-resizeable matrix with R rows and C columns.
/// Intended for 3D use (size 3x3 and 4x4).
/// Important: <b>Matrices here are in row-major order whereas OpenGL is column-major.</b>
/// Params:
///   T = type of elements
///   R = number of rows
///   C = number of columns
struct Matrix(T, int R, int C)
{
    public
    {
        static assert(R >= 1 && C >= 1);

        alias Vector!(T, C) row_t;
        alias Vector!(T, R) column_t;

        enum bool isSquare = (R == C);

        // fields definition
        union
        {
            T[C*R] v;        // all elements
            row_t[R] rows;   // all rows
            T[C][R] c;       // components
        }

        @nogc this(U...)(U values) pure nothrow
        {
            static if ((U.length == C*R) && allSatisfy!(isTAssignable, U))
            {
                // construct with components
                foreach(int i, x; values)
                    v[i] = x;
            }
            else static if ((U.length == 1) && (isAssignable!(U[0])) && (!is(U[0] : Matrix)))
            {
                // construct with assignment
                opAssign!(U[0])(values[0]);
            }
            else static assert(false, "cannot create a matrix from given arguments");
        }

        /// Construct a matrix from columns.
        @nogc static Matrix fromColumns(column_t[] columns) pure nothrow
        {
            assert(columns.length == C);
            Matrix res;
            for (int i = 0; i < R; ++i)
                for (int j = 0; j < C; ++j)
                {
                   res.c[i][j] = columns[j][i];
                }
            return res;
        }

        /// Construct a matrix from rows.
        @nogc static Matrix fromRows(row_t[] rows) pure nothrow
        {
            assert(rows.length == R);
            Matrix res;
            res.rows[] = rows[];
            return res;
        }

        /// Construct matrix with a scalar.
        @nogc this(U)(T x) pure nothrow
        {
            for (int i = 0; i < _N; ++i)
                v[i] = x;
        }

        /// Assign with a scalar.
        @nogc ref Matrix opAssign(U : T)(U x) pure nothrow
        {
            for (int i = 0; i < R * C; ++i)
                v[i] = x;
            return this;
        }

        /// Assign with a samey matrice.
        @nogc ref Matrix opAssign(U : Matrix)(U x) pure nothrow
        {
            for (int i = 0; i < R * C; ++i)
                v[i] = x.v[i];
            return this;
        }

        /// Assign from other small matrices (same size, compatible type).
        @nogc ref Matrix opAssign(U)(U x) pure nothrow
            if (isMatrixInstantiation!U
                && is(U._T : _T)
                && (!is(U: Matrix))
                && (U._R == R) && (U._C == C))
        {
            for (int i = 0; i < R * C; ++i)
                v[i] = x.v[i];
            return this;
        }

        /// Assign with a static array of size R * C.
        @nogc ref Matrix opAssign(U)(U x) pure nothrow
            if ((isStaticArray!U)
                && is(typeof(x[0]) : T)
                && (U.length == R * C))
        {
            for (int i = 0; i < R * C; ++i)
                v[i] = x[i];
            return this;
        }

        /// Assign with a dynamic array of size R * C.
        @nogc ref Matrix opAssign(U)(U x) pure nothrow
            if ((isDynamicArray!U)
                && is(typeof(x[0]) : T))
        {
            assert(x.length == R * C);
            for (int i = 0; i < R * C; ++i)
                v[i] = x[i];
            return this;
        }

        /// Return a pointer to content.
        @nogc inout(T)* ptr() pure inout nothrow @property
        {
            return v.ptr;
        }

        /// Returns a column as a vector
        /// Returns: column j as a vector.
        @nogc column_t column(int j) pure const nothrow
        {
            column_t res = void;
            for (int i = 0; i < R; ++i)
                res.v[i] = c[i][j];
            return res;
        }

        /// Returns a row as a vector
        /// Returns: row i as a vector.
        @nogc row_t row(int i) pure const nothrow
        {
            return rows[i];
        }

        /// Covnerts to pretty string.
        string toString() const nothrow
        {
            try
                return format("%s", v);
            catch (Exception e)
                assert(false); // should not happen since format is right
        }

        /// Matrix * scalar multiplication.
        @nogc Matrix opBinary(string op)(T factor) pure const nothrow if (op == "*")
        {
            Matrix result = void;

            for (int i = 0; i < R; ++i)
            {
                for (int j = 0; j < C; ++j)
                {
                    result.c[i][j] = c[i][j] * factor;
                }
            }
            return result;
        }

        /// Matrix * vector multiplication.
        @nogc column_t opBinary(string op)(row_t x) pure const nothrow if (op == "*")
        {
            column_t res = void;
            for (int i = 0; i < R; ++i)
            {
                T sum = 0;
                for (int j = 0; j < C; ++j)
                {
                    sum += c[i][j] * x.v[j];
                }
                res.v[i] = sum;
            }
            return res;
        }

        /// Matrix * matrix multiplication.
        @nogc auto opBinary(string op, U)(U x) pure const nothrow
            if (isMatrixInstantiation!U && (U._R == C) && (op == "*"))
        {
            Matrix!(T, R, U._C) result = void;

            for (int i = 0; i < R; ++i)
            {
                for (int j = 0; j < U._C; ++j)
                {
                    T sum = 0;
                    for (int k = 0; k < C; ++k)
                        sum += c[i][k] * x.c[k][j];
                    result.c[i][j] = sum;
                }
            }
            return result;
        }

        /// Matrix add and substraction.
        @nogc Matrix opBinary(string op, U)(U other) pure const nothrow
            if (is(U : Matrix) && (op == "+" || op == "-"))
        {
            Matrix result = void;

            for (int i = 0; i < R; ++i)
            {
                for (int j = 0; j < C; ++j)
                {
                    mixin("result.c[i][j] = c[i][j] " ~ op ~ " other.c[i][j];");
                }
            }
            return result;
        }

        /// Assignment operator with another samey matrix.
        @nogc ref Matrix opOpAssign(string op, U)(U operand) pure nothrow if (is(U : Matrix))
        {
            mixin("Matrix result = this " ~ op ~ " operand;");
            return opAssign!Matrix(result);
        }

        /// Assignment operator with another samey matrix.
        @nogc ref Matrix opOpAssign(string op, U)(U operand) pure nothrow if (isConvertible!U)
        {
            Matrix conv = operand;
            return opOpAssign!op(conv);
        }

        /// Cast to other matrix types.
        /// If the size are different, the resulting matrix is truncated
        /// and/or filled with identity coefficients.
        @nogc U opCast(U)() pure const nothrow if (isMatrixInstantiation!U)
        {
            U res = U.identity();
            enum minR = R < U._R ? R : U._R;
            enum minC = C < U._C ? C : U._C;
            for (int i = 0; i < minR; ++i)
                for (int j = 0; j < minC; ++j)
                {
                    res.c[i][j] = cast(U._T)(c[i][j]);
                }
            return res;
        }

        @nogc bool opEquals(U)(U other) pure const nothrow if (is(U : Matrix))
        {
            for (int i = 0; i < R * C; ++i)
                if (v[i] != other.v[i])
                    return false;
            return true;
        }

        @nogc bool opEquals(U)(U other) pure const nothrow
            if ((isAssignable!U) && (!is(U: Matrix)))
        {
            Matrix conv = other;
            return opEquals(conv);
        }

        // +matrix, -matrix, ~matrix, !matrix
        @nogc Matrix opUnary(string op)() pure const nothrow if (op == "+" || op == "-" || op == "~" || op == "!")
        {
            Matrix res = void;
            for (int i = 0; i < N; ++i)
                mixin("res.v[i] = " ~ op ~ "v[i];");
            return res;
        }

        /// Convert 3x3 rotation matrix to quaternion.
        /// See_also: 3D Math Primer for Graphics and Game Development.
        @nogc U opCast(U)() pure const nothrow if (isQuaternionInstantiation!U
                                                   && is(U._T : _T)
                                                   && (_R == 3) && (_C == 3))
        {
            T fourXSquaredMinus1 = c[0][0] - c[1][1] - c[2][2];
            T fourYSquaredMinus1 = c[1][1] - c[0][0] - c[2][2];
            T fourZSquaredMinus1 = c[2][2] - c[0][0] - c[1][1];
            T fourWSquaredMinus1 = c[0][0] + c[1][1] + c[2][2];

            int biggestIndex = 0;
            T fourBiggestSquaredMinus1 = fourWSquaredMinus1;

            if(fourXSquaredMinus1 > fourBiggestSquaredMinus1)
            {
                fourBiggestSquaredMinus1 = fourXSquaredMinus1;
                biggestIndex = 1;
            }

            if(fourYSquaredMinus1 > fourBiggestSquaredMinus1)
            {
                fourBiggestSquaredMinus1 = fourYSquaredMinus1;
                biggestIndex = 2;
            }

            if(fourZSquaredMinus1 > fourBiggestSquaredMinus1)
            {
                fourBiggestSquaredMinus1 = fourZSquaredMinus1;
                biggestIndex = 3;
            }

            T biggestVal = sqrt(fourBiggestSquaredMinus1 + 1) / 2;
            T mult = 1 / (biggestVal * 4);

            U quat;
            switch(biggestIndex)
            {
                case 1:
                    quat.w = (c[1][2] - c[2][1]) * mult;
                    quat.x = biggestVal;
                    quat.y = (c[0][1] + c[1][0]) * mult;
                    quat.z = (c[2][0] + c[0][2]) * mult;
                    break;

                case 2:
                    quat.w = (c[2][0] - c[0][2]) * mult;
                    quat.x = (c[0][1] + c[1][0]) * mult;
                    quat.y = biggestVal;
                    quat.z = (c[1][2] + c[2][1]) * mult;
                    break;

                case 3:
                    quat.w = (c[0][1] - c[1][0]) * mult;
                    quat.x = (c[2][0] + c[0][2]) * mult;
                    quat.y = (c[1][2] + c[2][1]) * mult;
                    quat.z = biggestVal;
                    break;

                default: // biggestIndex == 0
                    quat.w = biggestVal;
                    quat.x = (c[1][2] - c[2][1]) * mult;
                    quat.y = (c[2][0] - c[0][2]) * mult;
                    quat.z = (c[0][1] - c[1][0]) * mult;
                    break;
            }

            return quat;
        }

        /// Converts a 4x4 rotation matrix to quaternion.
        @nogc U opCast(U)() pure const nothrow if (isQuaternionInstantiation!U
                                                   && is(U._T : _T)
                                                   && (_R == 4) && (_C == 4))
        {
            auto m3 = cast(mat3!T)(this);
            return cast(U)(m3);
        }

        static if (isSquare && isFloatingPoint!T && R == 1)
        {
            /// Returns an inverted copy of this matrix
            /// Returns: inverse of matrix.
            /// Note: Matrix inversion is provided for 1x1, 2x2, 3x3 and 4x4 floating point matrices.
            @nogc Matrix inverse() pure const nothrow
            {
                return Matrix( 1 / c[0][0]);
            }
        }

        static if (isSquare && isFloatingPoint!T && R == 2)
        {
            /// Returns an inverted copy of this matrix
            /// Returns: inverse of matrix.
            /// Note: Matrix inversion is provided for 1x1, 2x2, 3x3 and 4x4 floating point matrices.
            @nogc Matrix inverse() pure const nothrow
            {
                T invDet = 1 / (c[0][0] * c[1][1] - c[0][1] * c[1][0]);
                return Matrix( c[1][1] * invDet, -c[0][1] * invDet,
                                   -c[1][0] * invDet,  c[0][0] * invDet);
            }
        }

        static if (isSquare && isFloatingPoint!T && R == 3)
        {
            /// Returns an inverted copy of this matrix
            /// Returns: inverse of matrix.
            /// Note: Matrix inversion is provided for 1x1, 2x2, 3x3 and 4x4 floating point matrices.
            @nogc Matrix inverse() pure const nothrow
            {
                T det = c[0][0] * (c[1][1] * c[2][2] - c[2][1] * c[1][2])
                      - c[0][1] * (c[1][0] * c[2][2] - c[1][2] * c[2][0])
                      + c[0][2] * (c[1][0] * c[2][1] - c[1][1] * c[2][0]);
                T invDet = 1 / det;

                Matrix res = void;
                res.c[0][0] =  (c[1][1] * c[2][2] - c[2][1] * c[1][2]) * invDet;
                res.c[0][1] = -(c[0][1] * c[2][2] - c[0][2] * c[2][1]) * invDet;
                res.c[0][2] =  (c[0][1] * c[1][2] - c[0][2] * c[1][1]) * invDet;
                res.c[1][0] = -(c[1][0] * c[2][2] - c[1][2] * c[2][0]) * invDet;
                res.c[1][1] =  (c[0][0] * c[2][2] - c[0][2] * c[2][0]) * invDet;
                res.c[1][2] = -(c[0][0] * c[1][2] - c[1][0] * c[0][2]) * invDet;
                res.c[2][0] =  (c[1][0] * c[2][1] - c[2][0] * c[1][1]) * invDet;
                res.c[2][1] = -(c[0][0] * c[2][1] - c[2][0] * c[0][1]) * invDet;
                res.c[2][2] =  (c[0][0] * c[1][1] - c[1][0] * c[0][1]) * invDet;
                return res;
            }
        }

        static if (isSquare && isFloatingPoint!T && R == 4)
        {
            /// Returns an inverted copy of this matrix
            /// Returns: inverse of matrix.
            /// Note: Matrix inversion is provided for 1x1, 2x2, 3x3 and 4x4 floating point matrices.
            @nogc Matrix inverse() pure const nothrow
            {
                T det2_01_01 = c[0][0] * c[1][1] - c[0][1] * c[1][0];
                T det2_01_02 = c[0][0] * c[1][2] - c[0][2] * c[1][0];
                T det2_01_03 = c[0][0] * c[1][3] - c[0][3] * c[1][0];
                T det2_01_12 = c[0][1] * c[1][2] - c[0][2] * c[1][1];
                T det2_01_13 = c[0][1] * c[1][3] - c[0][3] * c[1][1];
                T det2_01_23 = c[0][2] * c[1][3] - c[0][3] * c[1][2];

                T det3_201_012 = c[2][0] * det2_01_12 - c[2][1] * det2_01_02 + c[2][2] * det2_01_01;
                T det3_201_013 = c[2][0] * det2_01_13 - c[2][1] * det2_01_03 + c[2][3] * det2_01_01;
                T det3_201_023 = c[2][0] * det2_01_23 - c[2][2] * det2_01_03 + c[2][3] * det2_01_02;
                T det3_201_123 = c[2][1] * det2_01_23 - c[2][2] * det2_01_13 + c[2][3] * det2_01_12;

                T det = - det3_201_123 * c[3][0] + det3_201_023 * c[3][1] - det3_201_013 * c[3][2] + det3_201_012 * c[3][3];
                T invDet = 1 / det;

                T det2_03_01 = c[0][0] * c[3][1] - c[0][1] * c[3][0];
                T det2_03_02 = c[0][0] * c[3][2] - c[0][2] * c[3][0];
                T det2_03_03 = c[0][0] * c[3][3] - c[0][3] * c[3][0];
                T det2_03_12 = c[0][1] * c[3][2] - c[0][2] * c[3][1];
                T det2_03_13 = c[0][1] * c[3][3] - c[0][3] * c[3][1];
                T det2_03_23 = c[0][2] * c[3][3] - c[0][3] * c[3][2];
                T det2_13_01 = c[1][0] * c[3][1] - c[1][1] * c[3][0];
                T det2_13_02 = c[1][0] * c[3][2] - c[1][2] * c[3][0];
                T det2_13_03 = c[1][0] * c[3][3] - c[1][3] * c[3][0];
                T det2_13_12 = c[1][1] * c[3][2] - c[1][2] * c[3][1];
                T det2_13_13 = c[1][1] * c[3][3] - c[1][3] * c[3][1];
                T det2_13_23 = c[1][2] * c[3][3] - c[1][3] * c[3][2];

                T det3_203_012 = c[2][0] * det2_03_12 - c[2][1] * det2_03_02 + c[2][2] * det2_03_01;
                T det3_203_013 = c[2][0] * det2_03_13 - c[2][1] * det2_03_03 + c[2][3] * det2_03_01;
                T det3_203_023 = c[2][0] * det2_03_23 - c[2][2] * det2_03_03 + c[2][3] * det2_03_02;
                T det3_203_123 = c[2][1] * det2_03_23 - c[2][2] * det2_03_13 + c[2][3] * det2_03_12;

                T det3_213_012 = c[2][0] * det2_13_12 - c[2][1] * det2_13_02 + c[2][2] * det2_13_01;
                T det3_213_013 = c[2][0] * det2_13_13 - c[2][1] * det2_13_03 + c[2][3] * det2_13_01;
                T det3_213_023 = c[2][0] * det2_13_23 - c[2][2] * det2_13_03 + c[2][3] * det2_13_02;
                T det3_213_123 = c[2][1] * det2_13_23 - c[2][2] * det2_13_13 + c[2][3] * det2_13_12;

                T det3_301_012 = c[3][0] * det2_01_12 - c[3][1] * det2_01_02 + c[3][2] * det2_01_01;
                T det3_301_013 = c[3][0] * det2_01_13 - c[3][1] * det2_01_03 + c[3][3] * det2_01_01;
                T det3_301_023 = c[3][0] * det2_01_23 - c[3][2] * det2_01_03 + c[3][3] * det2_01_02;
                T det3_301_123 = c[3][1] * det2_01_23 - c[3][2] * det2_01_13 + c[3][3] * det2_01_12;

                Matrix res = void;
                res.c[0][0] = - det3_213_123 * invDet;
                res.c[1][0] = + det3_213_023 * invDet;
                res.c[2][0] = - det3_213_013 * invDet;
                res.c[3][0] = + det3_213_012 * invDet;

                res.c[0][1] = + det3_203_123 * invDet;
                res.c[1][1] = - det3_203_023 * invDet;
                res.c[2][1] = + det3_203_013 * invDet;
                res.c[3][1] = - det3_203_012 * invDet;

                res.c[0][2] = + det3_301_123 * invDet;
                res.c[1][2] = - det3_301_023 * invDet;
                res.c[2][2] = + det3_301_013 * invDet;
                res.c[3][2] = - det3_301_012 * invDet;

                res.c[0][3] = - det3_201_123 * invDet;
                res.c[1][3] = + det3_201_023 * invDet;
                res.c[2][3] = - det3_201_013 * invDet;
                res.c[3][3] = + det3_201_012 * invDet;
                return res;
            }
        }

        /// Returns a transposed copy of this matrix
        /// Returns: transposed matrice.
        @nogc Matrix!(T, C, R) transposed() pure const nothrow
        {
            Matrix!(T, C, R) res;
            for (int i = 0; i < C; ++i)
                for (int j = 0; j < R; ++j)
                    res.c[i][j] = c[j][i];
            return res;
        }

        static if (isSquare && R > 1)
        {
            /// Makes a diagonal matrix from a vector.
            @nogc static Matrix diag(Vector!(T, R) v) pure nothrow
            {
                Matrix res = void;
                for (int i = 0; i < R; ++i)
                    for (int j = 0; j < C; ++j)
                        res.c[i][j] = (i == j) ? v.v[i] : 0;
                return res;
            }

            /// In-place translate by (v, 1)
            @nogc void translate(Vector!(T, R-1) v) pure nothrow
            {
                for (int i = 0; i < R; ++i)
                {
                    T dot = 0;
                    for (int j = 0; j + 1 < C; ++j)
                        dot += v.v[j] * c[i][j];

                    c[i][C-1] += dot;
                }
            }

            /// Make a translation matrix.
            @nogc static Matrix translation(Vector!(T, R-1) v) pure nothrow
            {
                Matrix res = identity();
                for (int i = 0; i + 1 < R; ++i)
                    res.c[i][C-1] += v.v[i];
                return res;
            }

            /// In-place matrix scaling.
            void scale(Vector!(T, R-1) v) pure nothrow
            {
                for (int i = 0; i < R; ++i)
                    for (int j = 0; j + 1 < C; ++j)
                        c[i][j] *= v.v[j];
            }

            /// Make a scaling matrix.
            @nogc static Matrix scaling(Vector!(T, R-1) v) pure nothrow
            {
                Matrix res = identity();
                for (int i = 0; i + 1 < R; ++i)
                    res.c[i][i] = v.v[i];
                return res;
            }
        }

        // rotations are implemented for 3x3 and 4x4 matrices.
        static if (isSquare && (R == 3 || R == 4) && isFloatingPoint!T)
        {
            @nogc public static Matrix rotateAxis(int i, int j)(T angle) pure nothrow
            {
                Matrix res = identity();
                const T cosa = cos(angle);
                const T sina = sin(angle);
                res.c[i][i] = cosa;
                res.c[i][j] = -sina;
                res.c[j][i] = sina;
                res.c[j][j] = cosa;
                return res;
            }

            /// Rotate along X axis
            /// Returns: rotation matrix along axis X
            alias rotateAxis!(1, 2) rotateX;

            /// Rotate along Y axis
            /// Returns: rotation matrix along axis Y
            alias rotateAxis!(2, 0) rotateY;

            /// Rotate along Z axis
            /// Returns: rotation matrix along axis Z
            alias rotateAxis!(0, 1) rotateZ;

            /// Similar to the glRotate matrix, however the angle is expressed in radians
            /// See_also: $(LINK http://www.cs.rutgers.edu/~decarlo/428/gl_man/rotate.html)
            @nogc static Matrix rotation(T angle, vec3!T axis) pure nothrow
            {
                Matrix res = identity();
                const T c = cos(angle);
                const oneMinusC = 1 - c;
                const T s = sin(angle);
                axis = axis.normalized();
                T x = axis.x,
                  y = axis.y,
                  z = axis.z;
                T xy = x * y,
                  yz = y * z,
                  xz = x * z;

                res.c[0][0] = x * x * oneMinusC + c;
                res.c[0][1] = x * y * oneMinusC - z * s;
                res.c[0][2] = x * z * oneMinusC + y * s;
                res.c[1][0] = y * x * oneMinusC + z * s;
                res.c[1][1] = y * y * oneMinusC + c;
                res.c[1][2] = y * z * oneMinusC - x * s;
                res.c[2][0] = z * x * oneMinusC - y * s;
                res.c[2][1] = z * y * oneMinusC + x * s;
                res.c[2][2] = z * z * oneMinusC + c;
                return res;
            }
        }

        // 4x4 specific transformations for 3D usage
        static if (isSquare && R == 4 && isFloatingPoint!T)
        {
            /// Orthographic projection
            /// Returns: orthographic projection.
            @nogc static Matrix orthographic(T left, T right, T bottom, T top, T near, T far) pure nothrow
            {
                T dx = right - left,
                  dy = top - bottom,
                  dz = far - near;

                T tx = -(right + left) / dx;
                T ty = -(top + bottom) / dy;
                T tz = -(far + near)   / dz;

                return Matrix(2 / dx,   0,      0,    tx,
                                0,    2 / dy,   0,    ty,
                                0,      0,   -2 / dz, tz,
                                0,      0,      0,     1);
            }

            /// Perspective projection
            /// Returns: perspective projection.
            @nogc static Matrix perspective(T FOVInRadians, T aspect, T zNear, T zFar) pure nothrow
            {
                T f = 1 / tan(FOVInRadians / 2);
                T d = 1 / (zNear - zFar);

                return Matrix(f / aspect, 0,                  0,                    0,
                                       0, f,                  0,                    0,
                                       0, 0, (zFar + zNear) * d, 2 * d * zFar * zNear,
                                       0, 0,                 -1,                    0);
            }

            /// Look At projection
            /// Returns: "lookAt" projection.
            /// Thanks to vuaru for corrections.
            @nogc static Matrix lookAt(vec3!T eye, vec3!T target, vec3!T up) pure nothrow
            {
                vec3!T Z = (eye - target).normalized();
                vec3!T X = cross(-up, Z).normalized();
                vec3!T Y = cross(Z, -X);

                return Matrix(-X.x,        -X.y,        -X.z,      dot(X, eye),
                               Y.x,         Y.y,         Y.z,     -dot(Y, eye),
                               Z.x,         Z.y,         Z.z,     -dot(Z, eye),
                               0,           0,           0,        1);
            }

            /// Extract frustum from a 4x4 matrice.
            @nogc Frustum!T frustum() pure const nothrow
            {
                auto left   = Plane!T(row(3) + row(0));
                auto right  = Plane!T(row(3) - row(0));
                auto top    = Plane!T(row(3) - row(1));
                auto bottom = Plane!T(row(3) + row(1));
                auto near   = Plane!T(row(3) + row(2));
                auto far    = Plane!T(row(3) - row(2));
                return Frustum!T(left, right, top, bottom, near, far);
            }

        }
    }

    package
    {
        alias T _T;
        enum _R = R;
        enum _C = C;
    }

    private
    {
        template isAssignable(T)
        {
            enum bool isAssignable = std.traits.isAssignable!(Matrix, T);
        }

        template isConvertible(T)
        {
            enum bool isConvertible = (!is(T : Matrix)) && isAssignable!T;
        }

        template isTAssignable(U)
        {
            enum bool isTAssignable = std.traits.isAssignable!(T, U);
        }

        template isRowConvertible(U)
        {
            enum bool isRowConvertible = is(U : row_t);
        }

        template isColumnConvertible(U)
        {
            enum bool isColumnConvertible = is(U : column_t);
        }
    }

    public
    {
        /// Construct an identity matrix
        /// Returns: an identity matrix.
        /// Note: the identity matrix, while only meaningful for square matrices,
        /// is also defined for non-square ones.
        @nogc static Matrix identity() pure nothrow
        {
            Matrix res = void;
            for (int i = 0; i < R; ++i)
                for (int j = 0; j < C; ++j)
                    res.c[i][j] = (i == j) ? 1 : 0;
            return res;
        }

        /// Construct an constant matrix
        /// Returns: a constant matrice.
        @nogc static Matrix constant(U)(U x) pure nothrow
        {
            Matrix res = void;

            for (int i = 0; i < R * C; ++i)
                res.v[i] = cast(T)x;
            return res;
        }
    }
}

template isMatrixInstantiation(U)
{
    private static void isMatrix(T, int R, int C)(Matrix!(T, R, C) x)
    {
    }

    enum bool isMatrixInstantiation = is(typeof(isMatrix(U.init)));
}

// GLSL is a big inspiration here
// we defines types with more or less the same names

///
template mat2x2(T) { alias Matrix!(T, 2, 2) mat2x2; }
///
template mat3x3(T) { alias Matrix!(T, 3, 3) mat3x3; }
///
template mat4x4(T) { alias Matrix!(T, 4, 4) mat4x4; }

// WARNING: in GLSL, first number is _columns_, second is rows
// It is the opposite here: first number is rows, second is columns
// With this convention mat2x3 * mat3x4 -> mat2x4.

///
template mat2x3(T) { alias Matrix!(T, 2, 3) mat2x3; }
///
template mat2x4(T) { alias Matrix!(T, 2, 4) mat2x4; }
///
template mat3x2(T) { alias Matrix!(T, 3, 2) mat3x2; }
///
template mat3x4(T) { alias Matrix!(T, 3, 4) mat3x4; }
///
template mat4x2(T) { alias Matrix!(T, 4, 2) mat4x2; }
///
template mat4x3(T) { alias Matrix!(T, 4, 3) mat4x3; }

// shorter names for most common matrices
alias mat2x2 mat2;///
alias mat3x3 mat3;///
alias mat4x4 mat4;///

// Define a lot of type names
// Most useful are probably mat4f and mat4d

alias mat2!byte   mat2b;///
alias mat2!short  mat2s;///
alias mat2!int    mat2i;///
alias mat2!long   mat2l;///
alias mat2!float  mat2f;///
alias mat2!double mat2d;///

alias mat3!byte   mat3b;///
alias mat3!short  mat3s;///
alias mat3!int    mat3i;///
alias mat3!long   mat3l;///
alias mat3!float  mat3f;///
alias mat3!double mat3d;///

alias mat4!byte   mat4b;///
alias mat4!short  mat4s;///
alias mat4!int    mat4i;///
alias mat4!long   mat4l;///
alias mat4!float  mat4f;///
alias mat4!double mat4d;///

alias mat2x2!byte   mat2x2b;///
alias mat2x2!short  mat2x2s;///
alias mat2x2!int    mat2x2i;///
alias mat2x2!long   mat2x2l;///
alias mat2x2!float  mat2x2f;///
alias mat2x2!double mat2x2d;///

alias mat2x3!byte   mat2x3b;///
alias mat2x3!short  mat2x3s;///
alias mat2x3!int    mat2x3i;///
alias mat2x3!long   mat2x3l;///
alias mat2x3!float  mat2x3f;///
alias mat2x3!double mat2x3d;///

alias mat2x4!byte   mat2x4b;///
alias mat2x4!short  mat2x4s;///
alias mat2x4!int    mat2x4i;///
alias mat2x4!long   mat2x4l;///
alias mat2x4!float  mat2x4f;///
alias mat2x4!double mat2x4d;///

alias mat3x2!byte   mat3x2b;///
alias mat3x2!short  mat3x2s;///
alias mat3x2!int    mat3x2i;///
alias mat3x2!long   mat3x2l;///
alias mat3x2!float  mat3x2f;///
alias mat3x2!double mat3x2d;///

alias mat3x3!byte   mat3x3b;///
alias mat3x3!short  mat3x3s;///
alias mat3x3!int    mat3x3i;///
alias mat3x3!long   mat3x3l;///
alias mat3x3!float  mat3x3f;///
alias mat3x3!double mat3x3d;///

alias mat3x4!byte   mat3x4b;///
alias mat3x4!short  mat3x4s;///
alias mat3x4!int    mat3x4i;///
alias mat3x4!long   mat3x4l;///
alias mat3x4!float  mat3x4f;///
alias mat3x4!double mat3x4d;///

alias mat4x2!byte   mat4x2b;///
alias mat4x2!short  mat4x2s;///
alias mat4x2!int    mat4x2i;///
alias mat4x2!long   mat4x2l;///
alias mat4x2!float  mat4x2f;///
alias mat4x2!double mat4x2d;///

alias mat4x3!byte   mat4x3b;///
alias mat4x3!short  mat4x3s;///
alias mat4x3!int    mat4x3i;///
alias mat4x3!long   mat4x3l;///
alias mat4x3!float  mat4x3f;///
alias mat4x3!double mat4x3d;///

alias mat4x4!byte   mat4x4b;///
alias mat4x4!short  mat4x4s;///
alias mat4x4!int    mat4x4i;///
alias mat4x4!long   mat4x4l;///
alias mat4x4!float  mat4x4f;///
alias mat4x4!double mat4x4d;///

unittest
{
    mat2i x = mat2i(0, 1,
                    2, 3);
    assert(x.c[0][0] == 0 && x.c[0][1] == 1 && x.c[1][0] == 2 && x.c[1][1] == 3);

    vec2i[2] cols = [vec2i(0, 2), vec2i(1, 3)];
    mat2i y = mat2i.fromColumns(cols[]);
    assert(y.c[0][0] == 0 && y.c[0][1] == 1 && y.c[1][0] == 2 && y.c[1][1] == 3);
    y = mat2i.fromRows(cols[]);
    assert(y.c[0][0] == 0 && y.c[1][0] == 1 && y.c[0][1] == 2 && y.c[1][1] == 3);
    y = y.transposed();

    assert(x == y);
    x = [0, 1, 2, 3];
    assert(x == y);

    mat2i z = x * y;
    assert(z == mat2i([2, 3, 6, 11]));
    vec2i vz = z * vec2i(2, -1);
    assert(vz == vec2i(1, 1));

    mat2f a = z;
    mat2d ad = a;
    ad += a;
    mat2f w = [4, 5, 6, 7];
    z = cast(mat2i)w;
    assert(w == z);

    {
        mat2x3f A;
        mat3x4f B;
        mat2x4f C = A * B;
    }

    assert(mat2i.diag(vec2i(1, 2)) == mat2i(1, 0,
                                            0, 2));

    // Construct with a single scalar
    auto D = mat4f(1.0f);
}
