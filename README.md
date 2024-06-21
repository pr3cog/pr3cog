# Introduction

This is the public release for Taype, a policy-agnostic language for oblivious
computation, and Coil, an optimizing FHE compiler. This public release is a
docker artifact incorporating the following publicly-available open-source
repositories:

- The Taype language compiler and examples: https://github.com/ccyip/taype.git
- The plaintext and EMP-toolkit drivers for Taype:
  https://github.com/ccyip/taype-drivers.git
- The Coil driver for Taype: https://github.com/ccyip/taype-driver-coil.git
- The VS Code syntax highlighting extension for Taype:
  https://github.com/ccyip/taype-vscode.git
- The Coil compiler: https://github.com/raghav198/controlled-leaking.git

The [Dockerfile](./Dockerfile) describes which versions of these repositories
are used and how these repositories and their dependencies are built and
installed. A [code-server](https://github.com/coder/code-server) (VS Code in the
browser) is also installed in the docker image, so that users can more easily
browse the source code.

Prebuilt docker images and the source code of the versions of Taype and Coil
used in these images are also available on
[Zenodo](https://doi.org/10.5281/zenodo.12211335).

# Getting Started

To run this artifact, first install [docker](https://www.docker.com/), and then
download one of our docker images from Zenodo, depending on your machine's
architecture. We provide images for amd64 (i.e. x86-64) and arm64 (e.g., for
Apple Silicon Mac). You can also build the docker image yourself using the
provided Dockerfile.

Before executing any docker commands, make sure that the docker daemon is
running: if you see `Cannot connect to the Docker daemon` in the output of
command `docker version`, then you need to start the daemon first. Check the
docker official documentation for instructions according to your operating
system and docker version.

Now you can load and run the downloaded docker image. The following commands
create an image called `pr3cog-image`, and start a container called `pr3cog`. We
expose the port `8080` for accessing the code-server.

``` sh
# <arch> is amd64 or arm64
mv pr3cog-image-<arch>.tar.xz pr3cog-image.tar.xz
# This command will take a minute or two
docker load -i pr3cog-image.tar.xz
docker run -dt -p 8080:8080 --name pr3cog pr3cog-image
```

To launch the code-server, run:

``` sh
docker exec -d pr3cog code-server
```

Now you can open the URL [localhost:8080](http://localhost:8080) (or
[127.0.0.1:8080](http://127.0.0.1:8080)) in a browser to access VS Code. Note
that some functionality may not work if you are using private mode or incognito
mode.

To access the container shell, run

``` sh
docker exec -it pr3cog bash --login
```

Your user name is `pr3cog` (without password) and the current directory is `~`
(i.e. `/home/pr3cog`). In the rest of this document, we assume commands are run
inside the container.

# Experimenting with Taype

Taype source code and examples are located at `~/taype`. A tutorial Taype file
`taype/examples/tutorial.tp` includes a lot of comments on how to write Taype
programs. We compile this file by invoking the Taype compiler:

``` sh
cd ~/taype
cabal run taype -- examples/tutorial/tutorial.tp
```

You can learn about the acceptable options to `taype` by running `cabal run
taype -- --help`.

The Taype compiler only generates OCaml code as libraries (e.g., the previous
command generates `examples/tutorial/tutorial.ml`). To make a runnable
application, we also have to write the "frontends" which handle I/O and other
non-oblivious business. For example, `examples/tutorial/test_elem.ml`, which
includes a lot of comments, showcases how we construct a test case as a runnable
executable.

We use the [Shake build system](https://shakebuild.com/) to streamline the
process of building and testing our examples. For instance, to build the
tutorial program, run:

``` sh
cabal run shake -- build/tutorial
```

We can manually run a compiled test case, e.g., `test_elem` with the provided
exmaple input files:

``` sh
cd examples/tutorial
# Run the test case with the plaintext driver.
# This driver only supports one party "trusted".
dune exec ./test_elem.exe plaintext trusted < test_elem.input
# Run the test case with the emp driver (based on EMP toolkit).
# It is a two-party computation with alice and bob.
dune exec ./test_elem.exe emp alice < test_elem.alice.input &
dune exec ./test_elem.exe emp bob < test_elem.bob.input
```

Other `shake` commands are available to run test cases in batch.

``` sh
# Clean the tutorial example
cabal run shake -- clean/tutorial
# Compile the tutorial example, and its test cases
# --verbose tells shake to print out the commands being run
cabal run shake -- --verbose build/tutorial
# Run all tutorial test cases
cabal run shake -- run/tutorial
# Run an individual test case
cabal run shake -- run/tutorial/test_elem
# Run a test case with a specific driver (supported drivers are emp and plaintext)
cabal run shake -- run/tutorial/test_elem/plaintext
# See the supported options and targets
cabal run shake -- --help
```

You can follow the tutorial and other case studies in the `examples` directory
to implement your own secure functionality, policies and test cases.

# Experimenting with Coil

The Coil compiler is located at `~/controlled-leaking`, with its examples /
benchmarks at `~/controlled-leaking/benchmarks`. For instance, to compile the
benchmark `linear_oram`, run:

```sh
cd ~/controlled-leaking
python main.py benchmarks/linear_oram.pita
```

You can find the commandline options to the Coil compiler by running `python
main.py -h`.

The Coil compiler generates optimized FHE programs as C++ code, which can be
further built and run as follows:

```sh
cd backends
mkdir build
cd build
# Compile generated C++ code
cmake -DTARGET=linear_oram.coil ..
make
# Example input
echo 9 2 3 12 6 8 7 1 4 5 0 10 21 16 30 13 6 > input
# Run FHE program
./linear_oram.coil input
```

# Experimenting with Taype and Coil integration

The Taype compiler is also able to generate FHE programs from high-level Taype
source code, by integrating the Coil compiler. A set of Taype examples using the
Coil driver can be found at `~/taype/examples/coil/coil.tp`. For instance, to
build and execute the `test_elem` example, run:

``` sh
cabal run shake -- build/coil
cd taype/examples/coil
# Run the offline phase
dune exec ./test_elem_offline.exe
# Run the online phase
dune exec ./test_elem_online.exe
```

The offline phase generates a (staged) Coil program (with the file extension
`pita`) specialized with the public information, and calls the Coil compiler to
generate efficient FHE programs (in the `coil-build` directory). On the other
hand, the online phase runs the compiled Coil program with the given input that
is consistent with the specialized public information.
