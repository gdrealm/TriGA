function [] = heat2d(fileName)
% -----------------------------------------------------------------------------%
% HEAT2D is a 2-dimensional finite element method solver for analyzing simple
% heat conduction problems. It reads in a matlab data file that contains the
% following information:

% node: A cell array of the elements in the mesh
% IEN: The element connectivity array

% heatGen: The internal heat generation

% tempBounds: a 1xn array containing the global node numbers of the nodes with
% dirichlet boundary conditions.

% boundTemp: a 1xn array containing the corresponding temperatures

% fluxBounds: a nx5 array containing the global number of the element with a side
% or sides on the global boundary, and a one in the subsequent column if the
% corresponding face is on  the global boundary. 

% boundFlux: an n x n_quad_points x 3 array containing the corresponding fluxes at the
% quadrature points for a given sides. 

% It writes out temperature to 'fileName'.
% -----------------------------------------------------------------------------%
load(fileName)
nel = numel(node);
nen = 10;
nNodes = length(NODE);
elem = IEN';

% 2D FEA Sovler
% Data initalization. Set global stiffness and forcing matrices to 0.
K(nNodes,nNodes) = sparse(0);
F(nNodes,1) = sparse(0);

% Load the data for the quadrature rule.
load quadData
Wt = W/2;

% Loop through the elements
for ee =1:nel
    % Display progress in 1% completion increments
    dispFreq = round(nel/100);
    if mod(ee,dispFreq) == 0
        clc
        fprintf('fea2d is %3.0f percent complete with the assembly process\n',ee/nel*100)
    end
    
    % initialize the local stiffness and forcing matrices
    k = zeros(nen);
    f = zeros(nen,1);
    
    % Conductivity and heat generation contributions to K and F, respectivly
    % Loop though the quadtrature points.
    for nq = 1:nQuad
        % Call the finite element subroutine to evaluate the basis functions
        % and their derivatives at the current quad point.
        [R, dR_dx, J_det]  = tri10(qPts(nq,1), qPts(nq,2),node{ee});
        J_det = abs(J_det);
        
        
        num = 0;
        den = 0;
        for n = 1:nen
            num = num + R(n)*node{ee}(n,1:2)*node{ee}(n,3);
            den = den + R(n)*node{ee}(n,3);
        end
        x = num/den;
        
        
        % Add the contribution of the current quad point to the local element
        % stiffness and forcing matrices.
        k = k + Wt(nq)*dR_dx*D*dR_dx'*J_det;
        f = f + Wt(nq)*heatGen(x(1),x(2))*R*J_det;
    end
    
    % Neumann BCs
    % See if the current element lies on a Neumann BC.
    if find(fluxBounds(:,1) == ee)
        j = find(fluxBounds(:,1) == ee);
        % Loop through each of the sides on the current element that has a
        % Neumann condition. Most elements will have only one side on the
        % boundary (which will usually be the first side, the one between the
        % 1st and 2nd vertices. However, some elements will have two sides on a
        % boundary, such as what happens at the corner of the domain.
        
        % Loop over sides that are on the global boundary.
        for s = 1:3
            if fluxBounds(j,s+1) == 1
                
                % Loop through quadrature points.
                for nbq = 1:nbQuad
                    
                    % Do quadrature along the boundary by scaling the line gauss
                    % quadrature rule to integrate the y = 0 side of the
                    % parent triangle. This is consistent with the convention
                    % of putting the curved edge between the 1st and second
                    % nodes.
                    
                    % Scale the locations of quadrature from [-1,1]  to [0 1]
                    if s == 1
                        xi = 1/2*(qPtsb(nbq)+1);
                        eta = 0;
                        scale  = 2;
                        Wb01 = Wb/scale;
                        
                    elseif s == 2
                        xi = 1/2*(qPtsb(nbq)+1);
                        eta = 1 - 1/2*(qPtsb(nbq)+1);
                        scale  = 2;
                        Wb01 = Wb/scale;
                        
                    elseif s == 3
                        xi = 0;
                        eta = 1/2*(qPtsb(nbq)+1);
                        scale  = 2;
                        Wb01 = Wb/scale;
                        
                    end
                    
                    % Calculate the contribution of the Neumann BCs to the local
                    % forcing vector.
                    [R,J_detb]  = tri10b(xi, eta, node{ee},s);
                    J_detb = abs(J_detb);
                    f = f + Wb01(nbq)*boundFlux(j,nbq,s)*R*J_detb;
                    
                end
            else
                continue
            end
        end
    end
    
    
    
    % Assemble k and f to the glabal matrices, K and F.
    for b = 1:nen
        for a = 1:b
            K(IEN(a,ee),IEN(b,ee)) = K(IEN(a,ee),IEN(b,ee)) + k(a,b);
        end
        F(IEN(b,ee)) = F(IEN(b,ee)) + f(b);
    end
end

% Fill in the bottom part of the the K matrix .
K = K + K' - K.*speye(size(K));

% ----------Go Back and take care of dirichlet boundary conditions-------------%
disp(' Taking care of diriclet BCs...')

[Ki,Kj,~] = find(K);
for ii = 1:length(tempBounds)
    col = tempBounds(ii);
    row = Ki(Kj == col);
    for j = 1:length(row)
        if row(j)~=col
            F(row(j)) = F(row(j))-K(row(j),col)*boundTemp(ii);
        end
    end
    
    K(col,:) = zeros(1,length(K));
    K(:,col) = zeros(length(K),1);
    
    K(tempBounds(ii),tempBounds(ii)) = 1;
    F(tempBounds(ii)) = boundTemp(ii);
    
end

disp('Solving the System...')
% Solve the system.
temp = K\F;

disp('Saving Results')
% Save temp out to 'fileName'
save(fileName,'temp','-append')

disp('Done')
return

