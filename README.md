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
docker run -it \
  --mount type=bind,source=/path/to/controlled-leaking,target=/root/controlled-leaking \
  coil-image
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

## Build and test taype + coil

The file `Dockerfile` shows how to install the dependencies. To build this
docker image, run:

``` sh
docker build -t coil-image .
```

The image does not include the taype and coil source code.

To run this docker, and mount the necessary source code:

``` sh
docker run -it --name coil \
  --mount type=bind,source=/path/to/controlled-leaking,target=/home/pr3cog/controlled-leaking \
  --mount type=bind,source=/path/to/taype-driver-coil,target=/home/pr3cog/taype-driver-coil \
  --mount type=bind,source=/path/to/taype,target=/home/pr3cog/taype \
  coil-image
```

To install the coil driver, run the following commands in the docker container:

``` sh
cd taype-driver-coil
dune build
dune install
```

To run a taype example with the coil backend, we first need to build the taype
compiler and then build the examples. This can be done in the host machine or in
the docker container, with the generated OCaml source code as output. See the
taype project README for instructions.

After generating the OCaml source code, we can run the example:

``` sh
cd taype/examples/coil
dune build
# Run the offline phase
dune exec ./test_elem_offline.exe
# Run the online phase
dune exec ./test_elem_online.exe
```

The offline phase generates the (staged) coil program (with file extension
`pita`) specialized with the public information, and compiles it with the coil
compiler (in the `coil-build` directory).

The online phase runs the compiled coil program with the given input that is
consistent with the specialized public information.
