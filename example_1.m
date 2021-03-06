% #------------------------------------------------------------------------
% EXAMPLE_1
% This is an example on how to use kinematic solver.
% #------------------------------------------------------------------------
clear; clear kinSolver.element; clear kinSolver.indexer; % Workspace cleanup (additional clears just in case)

A=[0 0]'; B=[0 4]'; C=[6 10]'; D=[0 10]'; E=[-.5 2]'; F=[.5 2]'; G=[3.5 6.5]'; H=[2.5 7.5]';
C1=[0 2]'; C2=[3 7]'; C3=[3 10]';

solver = kinSolver.solver();
ground = solver.getGround();
ground.addPoint(A); ground.addPoint(D);

el_1 = kinSolver.element(C1);
el_1.addPoint(A); el_1.addPoint(B); el_1.addPoint(E); el_1.addPoint(F);

el_2 = kinSolver.element(C2);
el_2.addPoint(B); el_2.addPoint(C); el_2.addPoint(G); el_2.addPoint(H);

el_3 = kinSolver.element(C3);
el_3.addPoint(C);

el_1.add_K_JointConstr(ground, A);
el_1.add_K_JointConstr(el_2, B);
el_2.add_K_JointConstr(el_3, C);
el_3.add_K_PrismConstr(ground, C, D);

% el_1.add_D_JointConstr(ground, A, @(t) t*pi/6, @(t) pi/6, @(t) 0); % Option 1
el_3.add_D_PrismConstr(ground, C, D, @(t) (-sin(t*pi)+1)*6, @(t) -6*pi*cos(t*pi), ...
    @(t) 6*pi*pi*sin(t*pi)); % Option 2

% Draw elements
solver.drawMechanism();

% Solve mechanism
solver.solve([0:0.05:1]);

% Create plots
figure; kinSolver.grapher.plot(el_1, 'x'); kinSolver.grapher.addPlot(el_1, 'x', B);

% Additional functions
% solver.animateSolution(); % Comment out for animation auto-play