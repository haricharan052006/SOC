function cyc = idc(dt, nRepeat)
%PROFILES.IDC Indian Driving Cycle (IDC) for 2-/3-wheelers.
%
%   cyc = profiles.idc()            % one 108 s cycle at 1 s
%   cyc = profiles.idc(dt, nRepeat) % repeated nRepeat times
%
% IDC is the cycle Indian e-2W ranges are certified on (AIS-039/AIS-040,
% CMVR Annexure II) - the "IDC range" in scooter brochures. Published
% summary values (AIS-039): 108 s, 0.658 km, average 21.93 km/h,
% max 42 km/h, max acceleration 0.65 m/s^2, max deceleration 0.63 m/s^2.
%
% Breakpoints below are reconstructed from an AIS-039 summary table: points
% up to 85 s are as published; the final 42 -> 0 km/h deceleration to 108 s
% is inferred. The reconstruction is checked against the published distance
% and average speed in scripts/week2_midc_load_profile.m. Verify against
% CMVR Annexure II before quoting it as the official trace.
%
% Output struct: same fields as profiles.midc.
if nargin < 1, dt = 1; end
if nargin < 2, nRepeat = 1; end

bp = [  0  0;  16  0;  22 14;  26 22;  30 13;  32 13;  37 23;  42 31;
       45 25;  49 25;  51 21;  59 34;  66 42;  69 37;  76 37;  78 34;
       85 42; 108  0];

t1    = (0:dt:bp(end,1))';
v1    = interp1(bp(:,1), bp(:,2), t1, 'linear');
v_kmh = [v1(1:end-1); repmat(v1(1:end-1), nRepeat - 1, 1); 0];   % back-to-back cycles
t     = (0:numel(v_kmh)-1)' * dt;
v     = v_kmh / 3.6;

cyc.name     = sprintf('IDC (Indian Driving Cycle) x %d', nRepeat);
cyc.t        = t;
cyc.v        = v;
cyc.v_kmh    = v_kmh;
cyc.a        = [diff(v) / dt; 0];
cyc.dt       = dt;
cyc.dist_km  = trapz(t, v) / 1000;
cyc.dur_s    = t(end);
cyc.vmax_kmh = max(v_kmh);
cyc.vavg_kmh = 3.6 * cyc.dist_km * 1000 / cyc.dur_s;
cyc.idle_pct = 100 * mean(v < 0.01);
cyc.amax     = max(cyc.a);
cyc.dmax     = -min(cyc.a);
end
