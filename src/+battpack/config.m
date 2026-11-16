function cfg = config()
%BATTPACK.CONFIG Pack topology for the e-scooter.
%
% 16S8P of 6 Ah 32700 LFP cells:
%   voltage  : 16 x 3.2 V   = 51.2 V nominal  (~40-58 V operating window)
%   capacity : 8  x 6 Ah    = 48 Ah
%   energy   : 51.2 V x 48 Ah = 2.46 kWh  (typical for a 90 km/h Indian e-scooter)
% 16S is chosen because 48 V-class motor controllers are standard for 2W.
cfg.Ns     = 16;                 % cells in series
cfg.Np     = 8;                  % cells in parallel per series group
cfg.cell   = lfp.cellParams();
cfg.Q_Ah   = cfg.Np * cfg.cell.Q_Ah;
cfg.V_nom  = cfg.Ns * cfg.cell.V_nom;
cfg.E_kWh  = cfg.Q_Ah * cfg.V_nom / 1000;
cfg.SOC_min_usable = 0.10;       % BMS stops discharge at 10 % to protect cells
end
