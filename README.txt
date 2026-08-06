GSC

Question: how much have financial frictions, working through changes in
the trade deficit, affected the process of structural transformation in
the United States?

The starting point is Reyes-Heroles, "Globalization and Structural
Change in the United States" (2017): two countries (USA, ROW), three
sectors (agriculture, manufacturing, services), Ricardian trade with
nonhomothetic CES demand. Two changes to it here.

  1. A financial friction. A wedge between the world interest rate and
     the rate US households face, backed out of the US Euler equation
     year by year. It moves US saving, which moves the trade deficit,
     which moves demand across sectors. Setting the wedge to one and
     re-solving the whole path is the counterfactual; the gap in the
     manufacturing value added share is the answer.

  2. A longer sample. 1965-2014, against 1970-2007 in the paper,
     splicing the WIOD long-run and 2016 releases.


LAYOUT

  analysis/code/data_processing/    raw files -> panels -> parameters
  analysis/code/data_processing_2/  same, alternate sector convention
  analysis/code/model/              parameters -> equilibrium -> counterfactual
  analysis/data/                    not in the repo, see DATA
  analysis/results/                 figures and tables
  paper/                            drafts and appendices

data_processing writes analysis/data/processed/*.csv, model reads them,
neither reaches across.


MODEL

  master.m      run this
  parameters.m  calibrated numbers
  variables.m   countries, sectors, slots
  loaddata.m    reads the CSVs
  baseline.m    steps 1-7,    what the data implies, including the wedge
  yearmodel.m   steps 9-15,   one year, given a guess of the US wage
  solveyear.m   step 8,       solves that guess
  solveyears.m  step 17,      the static block, year by year
  pathmodel.m   steps 18-21,  the intertemporal residuals
  solvepath.m   steps 16, 22, Newton on the path of net exports
  padyears.m    repeats the last year so the terminal condition binds
                after the sample
  vashares.m    US value added shares from a solved path

Everything is in exact hat algebra, counterfactual over baseline. Step
numbers match paper/ForwardSolve.tex.

master.m runs four scenarios and compares them on the change in the US
manufacturing value added share: the data, the friction frozen at its
1965 value, the friction removed, and no trade imbalances at all. The
wedge reaches real allocations only through net exports, so the last row
brackets the whole channel.

  matlab -batch "run('analysis/code/model/master.m')"


DATA

analysis/data is gitignored, 5.4 GB of WIOD releases and crosswalks.
To rebuild it:

  cd analysis/code/data_processing_2/matlab
  matlab -batch process_raw_data
  matlab -batch createpanels
  cd ../stata_code
  stata -b -e do run.do
  cd ../matlab
  matlab -batch recover_parameters

Paths are relative, so run each step from its own folder. The -e on
Stata is not optional; without it StataBE never exits.


THE TWO PIPELINES

data_processing is the baseline: distributive trade is a service and
government consumption is included. data_processing_2 counts trade as
goods, drops government, and writes to data/processed_2. The switch is
$GSC_TRADE_TO_GOODS in stata_code/0_setup.do; validate.do shows the two
agree exactly when it is off.


Needs MATLAB (base only) and Stata.
