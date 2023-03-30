# tinyODIN Low-Cost Digital Spiking Neural Network (SNN) Processor

tinyODIN is a low-cost spiking neural network (SNN) processor that was reduced to the simplest form of a crossbar array. It is adapted from the open-source ODIN SNN processor, which was published in 2019 in the [*IEEE Transactions on Biomedical Circuits and Systems* journal](#citation). tinyODIN embeds 256 12-bit leaky integrate-and-fire (LIF) neurons and 64k 4-bit synapses. As opposed to ODIN, there is no phenomenological Izhikevich neuron model nor online-learning synapses in tinyODIN.

In case you decide to use the tinyODIN HDL source code for academic or commercial use, we would appreciate it if you let us know; **feedback is welcome**.

> **Disclaimer --** Both the HDL code and the documentation of tinyODIN are derived from the [open-source repository of ODIN](https://github.com/ChFrenkel/ODIN).


## Citation

Upon usage of the HDL source code of tinyODIN, please cite the associated ODIN paper:

> [C. Frenkel, M. Lefebvre, J.-D. Legat and D. Bol, "A 0.086-mm² 12.7-pJ/SOP 64k-Synapse 256-Neuron Online-Learning Digital Spiking Neuromorphic Processor in 28-nm CMOS," *IEEE Transactions on Biomedical Circuits and Systems*, vol. 13, no. 1, pp. 145-158, 2019.]


## Documentation

Documentation on the contents, usage and features of the tinyODIN HDL source code can be found in the [doc folder](doc/).


## Licenses

> *Copyright (C) 2019-2022, Université catholique de Louvain (UCLouvain, Belgium), University of Zürich (UZH, Switzerland), Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands)*

> *The HDL source code of tinyODIN is under a Solderpad Hardware License v2.1 (see [LICENSE](LICENSE) file or https://solderpad.org/licenses/SHL-2.1/).*

> *The documentation of tinyODIN is under a Creative Commons Attribution 4.0 International License (see [doc/LICENSE](doc/LICENSE) file or http://creativecommons.org/licenses/by/4.0/).*
