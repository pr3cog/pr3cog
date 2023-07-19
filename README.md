# pr3cog

## Build and test coil

The file `Dockerfile.coil` shows how to install the dependencies. To build this
docker image, run:

``` sh
docker build -f Dockerfile.coil -t coil-image .
```

The image does not include the coil source code, as it is more convenient for
development to simply mount the source code directory.

To run this docker, and mount the coil source code directory:

``` sh
docker run -it --mount type=bind,source=/path/to/controlled-leaking,target=/root/controlled-leaking coil-image
```

As an example, we compile and run the `linear_oram` benchmark:

``` sh
cd /root/controlled-leaking
python main.py benchmarks/linear_oram.pita
# The generated code is in the backends directory
cd backends
mkdir build
cd build
# Without the .coil suffix, it compiles the slow, manual baseline version.
cmake -DTARGET=linear_oram.coil ..
make
./linear_oram.coil
```

To modify the input to the FHE program, edit the beginning of the `main`
function in file `backends/coil/main.cpp`.

In the `taype` branch, we can specify the input by providing the input file, and
we can also write the result to an output file:

``` sh
# input and output files are optional
./linear_oram.coil input output
```

The format of these files is very simple: just a list of numbers separated by
white space. The numbers specify the input and output arrays.
