#include <iostream>
#include <cuda_runtime.h>
#include <cuda.h>
#include <math_functions.h>
#include <opencv2/core/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/highgui.hpp>
#include "device_launch_parameters.h"

namespace jw {

	double reStart;
	double reEnd;
	double imStart;
	double imEnd;

	int width = 1024;
	int height = 768;
	int maxIter = 80;
	double zoomScale = 3.0;

	int blockSize = 1024;
	int numBlocks = ((width * height) + blockSize - 1) / blockSize;

	int *set;
	cv::Mat m;

	#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
	inline void gpuAssert(cudaError_t code, char *file, int line, bool abort = true)
	{
		if (code != cudaSuccess)
		{
			fprintf(stderr, "GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
			if (abort) exit(code);
		}
	}

	__global__ void CUDAMandelbrotTest(int *set, int maxIter, int width, int height, double reStart, double reEnd, double imStart, double imEnd) {
		
		int t = threadIdx.x;
		int b = blockIdx.x;

		int n = width * height;
		int index = b * 1024 + t;

		if (index >= n) return;

		int x = index % width;
		int y = index / width;

		double c_real = reStart + ((double)x / (double)width)  * (reEnd - reStart);
		double c_imaginary = imStart + ((double)y / (double)height) * (imEnd - imStart);

		double z_real = 0;
		double z_imaginary = 0;
		
		int iter = 0;
		while (sqrt(z_real*z_real + z_imaginary*z_imaginary) <= 2.0 && iter < maxIter) {
			
			double nr = z_real * z_real - z_imaginary * z_imaginary + c_real;
			double ni = 2 * z_real * z_imaginary + c_imaginary;

			z_real = nr;
			z_imaginary = ni;

			iter++;
		}
		set[index] = iter;
	}

	void ZoomIn(int x, int y, int width, int height, double scale) {

		double rx, iy;

		rx = (double)x / (double)width;
		iy = (double)y / (double)height;

		double rlen = (reEnd - reStart);
		double ihei = (imEnd - imStart);

		rx = reStart + rx * rlen;
		iy = imStart + iy * ihei;

		reStart = rx - rlen / scale;
		reEnd = rx + rlen / scale;
		imStart = iy - ihei / scale;
		imEnd = iy + ihei / scale;
	}

	void IntArray2D2Mat(int *set, cv::Mat &m, int width, int height, int maxIter) {

		for (int y = 0; y < height; y++) {
			for (int x = 0; x < width; x++) {

				int v = set[y*width + x];

				int hue = (int)(((double)v / (double)maxIter) * 255);
				int saturation = 180;
				int value = (v < maxIter) ? 255 : 0;

				m.at<cv::Vec3b>(y, x)[0] = hue;
				m.at<cv::Vec3b>(y, x)[1] = saturation;
				m.at<cv::Vec3b>(y, x)[2] = value;
			}
		}

		cv::cvtColor(m, m, cv::COLOR_HSV2BGR);
	}

	void Draw() {

		CUDAMandelbrotTest << <numBlocks, blockSize >> > (set, maxIter, width, height, reStart, reEnd, imStart, imEnd);

		cudaDeviceSynchronize();

		IntArray2D2Mat(set, m, width, height, maxIter);

		cv::imshow("Mandelbrot", m);
	}

	void InitView() {

		double ratio = (double)width / (double)height;

		reStart = -3.5;
		reEnd = 2.5;
		imStart = -((abs(reStart) + abs(reEnd)) * 1.0 / ratio / 2.0);
		imEnd = ((abs(reStart) + abs(reEnd)) * 1.0 / ratio / 2.0);
	}

	void CallBackFunc(int event, int x, int y, int flags, void* userdata)
	{
		if (event == cv::EVENT_LBUTTONDOWN)
		{
			ZoomIn(x, y, width, height, zoomScale);

			Draw();
		}
		else if (event == cv::EVENT_RBUTTONDOWN)
		{
			InitView();

			Draw();
		}/*
		else if (event == cv::EVENT_MBUTTONDOWN)
		{
			//cout << "Middle button of the mouse is clicked - position (" << x << ", " << y << ")" << endl;
		}
		else if (event == cv::EVENT_MOUSEMOVE)
		{
			//cout << "Mouse move over the window - position (" << x << ", " << y << ")" << endl;
		}*/
	}


	void CUDADrawMandelbrot() {

		int N = width * height;

		cudaMallocManaged(&set, N * sizeof(int*));

		m = cv::Mat(height, width, CV_8UC3);

		cv::namedWindow("Mandelbrot", 1);
		cv::setMouseCallback("Mandelbrot", CallBackFunc, NULL);

		InitView();
		Draw();

		cv::waitKey(0);

		m.release();

		cudaFree(set);

		gpuErrchk(cudaPeekAtLastError());
	}
}

int main(void)
{
	jw::CUDADrawMandelbrot();
	return 0;
}