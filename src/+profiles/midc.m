function cyc = midc(dt)
%PROFILES.MIDC Modified Indian Drive Cycle (MIDC) speed profile.
%
%   cyc = profiles.midc()      % 1 s resolution
%   cyc = profiles.midc(dt)
%
% MIDC (Indian type approval, AIS-137) = NEDC-style cycle with a low-powered
% extra-urban part:
%   Part 1 : 4 x ECE R15 elementary urban cycle   (4 x 195 s, max 50 km/h)
%   Part 2 : EUDC for low-powered vehicles        (400 s,     max 90 km/h)
%
% Both parts are defined in the regulation (UNECE R83 Annex 4a) as straight
% line segments: idle, constant acceleration, cruise, deceleration. The
% breakpoints below are those segments [time s, speed km/h]; gear-change
% pauses are kept as short constant-speed holds.
%
% Output struct: t [s], v [m/s], v_kmh, a [m/s^2], dist_km, dur_s, vmax_kmh,
% vavg_kmh, idle_pct, name.
if nargin < 1, dt = 1; end

% --- ECE R15 elementary urban cycle (195 s) ---
ece = [  0  0;  11  0;  15 15;  23 15;  25 10;  28  0;  % 15 km/h hop (15->10 in 2 s, 10->0 in 3 s)
        49  0;  54 15;  56 15;  61 32;  85 32;          % to 32 km/h (1 gear change)
        93 10;  96  0;                                  % stop
       117  0; 122 15; 124 15; 133 35; 135 35; 143 50;  % to 50 km/h (2 gear changes)
       155 50; 163 35; 176 35; 178 35; 185 10; 188  0;  % 50 -> 35 cruise -> stop
       195  0];

% --- EUDC, low-powered vehicles (400 s, capped at 90 km/h) ---
eudcLP = [  0  0;  20  0;  25 15;  27 15;  36 35;  38 35;  46 50;  48 50;  61 70;
          111 70; 119 50; 188 50; 201 70; 251 70; 286 90; 346 90;
          362 80; 370 50; 380  0; 400  0];

% Assemble: 4 x ECE + EUDC-LP
bp = ece;
for k = 1:3
    bp = [bp; ece(2:end,1) + bp(end,1), ece(2:end,2)]; %#ok<AGROW>
end
bp = [bp; eudcLP(2:end,1) + bp(end,1), eudcLP(2:end,2)];

t     = (0:dt:bp(end,1))';
v_kmh = interp1(bp(:,1), bp(:,2), t, 'linear');
v     = v_kmh / 3.6;
a     = [diff(v) / dt; 0];

cyc.name     = 'MIDC (4 x ECE R15 + EUDC low-powered)';
cyc.t        = t;
cyc.v        = v;
cyc.v_kmh    = v_kmh;
cyc.a        = a;
cyc.dt       = dt;
cyc.dist_km  = trapz(t, v) / 1000;
cyc.dur_s    = t(end);
cyc.vmax_kmh = max(v_kmh);
cyc.vavg_kmh = 3.6 * cyc.dist_km * 1000 / cyc.dur_s;
cyc.idle_pct = 100 * mean(v < 0.01);
cyc.part1_end_s = 4 * 195;
end
