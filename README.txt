GSC


LAYOUT

  analysis/code/data_processing/    raw files -> panels -> parameters
  analysis/code/model/              parameters -> equilibrium -> counterfactual
  analysis/data/                    not in the repo, see DATA
  analysis/results/                 figures and tables
  paper/                            drafts and appendices




MODEL

  master.m      run this
  parameters.m  calibrated numbers
  variables.m   countries, sectors, slots
  loaddata.m    reads the CSVs


  matlab -batch "run('analysis/code/model/master.m')"


DATA

