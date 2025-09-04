const std = @import("std");
pub const c = @import("pffft_c"); // Assumed to contain all C function bindings and struct/enum definitions.
const float_tolerance = 0.001;

const Type = enum(c_uint) {
    real = c.PFFFT_REAL,
    complex = c.PFFFT_COMPLEX,
};

/// for Complex Valued FFTs, input is input signal
/// output is transformed signal
///
/// working_buffer can be null for small N than its allocated on the stack
///
/// input output and working buffer must be of same length and have aligned memory
///
/// for Real Valued FFTs the output (frequency domain) only N + 1 bins are computed
/// the remaining bins can be ignored i.e. for frequency analysis or reconstructed
/// like this: from the first N/2 - 1, for index k > N/2
/// The magnitude of each frequency bin k is equal to the magnitude of N-k (|X_k| = |X_{N-k}|).
/// The phase of each frequency bin k is the negative of the phase of N-k (∠X_k = -∠X_{N-k}).
///
/// Also the imaginary parts of the DC bin and the Nyquist bin are always zero
/// the additional value is encoded in the first complex value where
/// the real part holds the real part of the DC-Component
/// the imaginary part holds the real part of the Nyquist-Component
pub fn Pffft(float: type, complex_or_real: type) type {
    return struct {
        const complex = std.math.Complex(float);
        const f32p = (float == f32);
        setup: ?*if (f32p) c.PFFFT_Setup else c.PFFFTD_Setup = null,
        const f_simd_arch = if (f32p) c.pffft_simd_arch else c.pffftd_simd_arch;
        const f_simd_size = if (f32p) c.pffft_simd_size else c.pffftd_simd_size;
        const f_new_setup = if (f32p) c.pffft_new_setup else c.pffftd_new_setup;
        const f_is_power_of_two = if (f32p) c.pffft_is_power_of_two else c.pffftd_is_power_of_two;
        const f_is_valid_size = if (f32p) c.pffft_is_valid_size else c.pffftd_is_valid_size;
        const f_destroy_setup = if (f32p) c.pffft_destroy_setup else c.pffftd_destroy_setup;
        const f_transform_ordered = if (f32p) c.pffft_transform_ordered else c.pffftd_transform_ordered;

        // prepare for performing transforms of size N -- the returned
        // PFFFT_Setup structure is read-only so it can safely be shared by
        // multiple concurrent threads.
        pub fn init(N: usize) !@This() {
            const size = to_c_int(N) catch @panic("int does not fit");
            const t: Type = if (std.math.Complex(float) == complex_or_real) .complex else if (float == complex_or_real) .real else unreachable;
            // const simd_arch = f_simd_arch();
            // const simd_size = f_simd_size();
            // std.log.warn("PFFT: simd: {s}, size: {}", .{ simd_arch, simd_size });
            const res = f_new_setup(size, @intFromEnum(t));
            return .{ .setup = res };
        }
        pub fn deinit(self: *@This()) void {
            f_destroy_setup(self.setup);
        }
        //  Perform a Fourier transform , The z-domain data is stored in the
        //  most efficient order for transforming it back, or using it for
        //  convolution. If you need to have its content sorted in the
        //  "usual" way, that is as an array of interleaved complex numbers,
        //  either use pffft_transform_ordered , or call pffft_zreorder after
        //  the forward fft, and before the backward fft.

        //  Transforms are not scaled: PFFFT_BACKWARD(PFFFT_FORWARD(x)) = N*x.
        //  Typically you will want to scale the backward transform by 1/N.

        //  The 'work' pointer should point to an area of N (2*N for complex
        //  fft) floats, properly aligned. If 'work' is NULL, then stack will
        //  be used instead (this is probably the best strategy for small
        //  FFTs, say for N < 16384). Threads usually have a small stack, that
        //  there's no sufficient amount of memory, usually leading to a crash!
        //  Use the heap with pffft_aligned_malloc() in this case.

        //  For a real forward transform (PFFFT_REAL | PFFFT_FORWARD) with real
        //  input with input(=transformation) length N, the output array is
        //  'mostly' complex:
        //    index k in 1 .. N/2 -1  corresponds to frequency k * Samplerate / N
        //    index k == 0 is a special case:
        //      the real() part contains the result for the DC frequency 0,
        //      the imag() part contains the result for the Nyquist frequency Samplerate/2
        //  both 0-frequency and half frequency components, which are real,
        //  are assembled in the first entry as  F(0)+i*F(N/2).
        //  With the output size N/2 complex values (=N real/imag values), it is
        //  obvious, that the result for negative frequencies are not output,
        //  cause of symmetry.
        //  input and output may alias.
        fn __fft(
            self: *@This(),
            input_buffer: anytype,
            output_buffer: anytype,
            working_buffer: ?[]complex_or_real,
            comptime inverse: bool,
        ) void {
            const x: [*c]float = @ptrCast(input_buffer.ptr);
            const y: [*c]float = @ptrCast(output_buffer.ptr);
            const w: [*c]float = if (working_buffer) |wb| @ptrCast(wb.ptr) else null;
            f_transform_ordered(self.setup, x, y, w, if (inverse) c.PFFFT_BACKWARD else c.PFFFT_FORWARD);
        }
        /// for real valued ffts the output / input holds only 0..N/2+1 frequency bins, and DC and Nyquists imaginary parts are always zero
        /// note the special encoding of the first index where the real parts of the DC and Nyquist Component
        /// are stored in the .re (first float) and .im (second float) respectively
        ///
        /// the transforms are not scaled that means you typically want to scale the inverse transform by 1/N.
        pub fn fft(
            self: *@This(),
            input_buffer: []complex_or_real,
            output_buffer: []complex,
            working_buffer: ?[]complex_or_real,
        ) void {
            self.__fft(input_buffer, output_buffer, working_buffer, false);
        }
        /// for real valued ffts the output / input holds only 0..N/2+1 frequency bins, and DC and Nyquists imaginary parts are always zero
        /// note the special encoding of the first index where the real parts of the DC and Nyquist Component
        /// are stored in the .re (first float) and .im (second float) respectively
        ///
        /// the transforms are not scaled that means you typically want to scale the inverse transform by 1/N.
        pub fn inverse_fft(
            self: *@This(),
            input_buffer: []complex,
            output_buffer: []complex_or_real,
            working_buffer: ?[]complex_or_real,
        ) void {
            self.__fft(input_buffer, output_buffer, working_buffer, true);
        }
    };
}

pub fn to_c_int(x: anytype) !c_int {
    return std.math.cast(c_int, x) orelse return error.CIntCastFailed;
}
