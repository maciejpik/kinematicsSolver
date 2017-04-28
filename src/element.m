classdef element < handle
    %ELEMENT Represents single element in mechanism
    %   Implements element of mechanism which has its own coordinate system
    %   in absolute coordinates approach.
    
    properties
        glob_indexer = indexer();
        index = 0;
        r_c = zeros(2, 1);
        fi_c = 0;
        
        solution = []; % Keeps information about time, q, q', q'' in format:
                       % solution(1, :) = time, solution(2-3-4, :) = q etc.
        
        cell_points = {}; % Points of element in local coordinate system
        vector_constraints = []; % Constraints for which the element is a
                                 % base element.
                                 % #TODO Another container should be
                                 % implemented so that it can keep
                                 % information about constraints which this
                                 % element constitue but not as a base
                                 % element, e.g. vector_of_known_constr
                                 
       % Software archictecture properties
       solver = struct('time', 0); % Reference to the solver which is known
                                   % to the object after call of
                                   % solver.broadcastSolverRef();
    end
    
    methods
        function obj = element( point )
            %   Constructor
            %   Input:
            %    * point - point being a center of gracity for the element
            obj.index = obj.glob_indexer.nextObj( obj );
            obj.r_c = [point(1) point(2)]';
        end
        function delete( obj )
            % Destructor removes references (handles) to the object
            % from static obj.glob_indexer property.
            delete( obj.glob_indexer.elements_array( obj.index + 1) );
        end
        function addPoint( obj, point )
            %   Adds point to cell array of element's points
            %   (obj.cell_points).
            point = [point(1) point(2)]';
            local_point = point - obj.r_c;
            obj.cell_points = [ obj.cell_points local_point ];
        end
        
        % Adding constraints methods
        % #TODO? This might be implemented in constraint classes. Think
        % over which place is more proper. Basically these methods checks
        % wheter creating give constraint can be added and then they create
        % it pushing the constraint to obj.vector_constraints.
        function add_K_JointConstr(obj, element, point)
            %   Input:
            %    * element - 2nd element
            %    * point - point common for both elements
            my_point_index = obj.whichIndex( point );
            element_point_index = element.whichIndex( point );
            if ( my_point_index * element_point_index ) < 0
                disp( sprintf('B��D DODAWANIA WI�ZU: Para obrotowa(%d, %d)', ...
                obj.index, element.index) );
                return
            end
            obj.vector_constraints = [ obj.vector_constraints ...
                kJointConstr(obj, my_point_index, element, element_point_index) ];
            disp( sprintf('DODANO WI�Z: Para obrotowa(%d, %d)', ...
                obj.index, element.index) );
        end
        function add_K_PrismConstr(obj, element, point_A, point_B)
            %   Method calculate automatically vector perpendicular to the
            %   axis of movement (v_B aka v_j).
            %   Input:
            %    * element - 2nd element
            %    * point_A - point on base element
            %    * point_B - point on 2nd element
            my_point_A_index = obj.whichIndex( point_A );
            element_point_B_index = element.whichIndex( point_B );
            if my_point_A_index < 0
                disp( sprintf('B��D DODAWANIA WI�ZU: Para post�powa(%d, %d) - b��dny punkt w el. bazowym', ...
                obj.index, element.index) );
                return
            elseif element_point_B_index < 0
                disp( sprintf('B��D DODAWANIA WI�ZU: Para post�powa(%d, %d) - b��dny punkt w el. do��czonym', ...
                obj.index, element.index) );
                return
            end
            % Find v_B element
            v_AB = point_B - point_A;
            v_B = rot(element.fi_c)' * [v_AB(2) -v_AB(1)]';
            % Push to obj.vector_constraints
            obj.vector_constraints = [ obj.vector_constraints ...
                kPrismConstr(obj, my_point_A_index, element, element_point_B_index, v_B) ];
            disp( sprintf('DODANO WI�Z: Para post�powa(%d, %d)', ...
                obj.index, element.index) );
        end
        function add_D_JointConstr(obj, element, point, f, f_prim, f_bis)
            % Checks if kinematic constraint of the type already exists
            % and on succeess adds driving constraint.
            % Input:
            %  * element - 2nd element
            %  * point - common point for both elements
            %  * f, f_prim, f_bis - passed as anonymous functions @(t) ...
            %       self explaining
            cstr_avail = false;
            for i = 1:numel( obj.vector_constraints )
                cstr = obj.vector_constraints(i);
                if element == cstr.el_B
                    if cstr.el_B.whichIndex( point ) == cstr.B_index
                        cstr_avail = true;
                        break
                    end
                end
            end
            % #TODO Implement check on future vector_of_known_constraints
            if ~cstr_avail
                disp( sprintf('B��D DODAWANIA WI�ZU: Para obrotowa - kieruj�cy(%d, %d) - brak wi�zu kinematycznego', ...
                obj.index, element.index) );
                return
            end
            obj.vector_constraints = [ obj.vector_constraints ...
                dJointConstr(obj, element, f, f_prim, f_bis) ];
            disp( sprintf('DODANO WI�Z: Para obrotowa - kieruj�cy(%d, %d)', ...
                obj.index, element.index) );
        end
        function add_D_PrismConstr(obj, element, point_A, point_B, f, f_prim, f_bis)
            % Checks if kinematic constraint of the type already exists
            % and on succeess adds driving constraint. It automatically
            % calculates u versor (u_B aka u_j).
            % Input:
            %  * element - 2nd element
            %  * point_A - point associated with base element
            %  * point_B - point associated with 2nd element
            %  * f, f_prim, f_bis - passed as anonymous functions @(t) ...
            %       self explaining
            cstr_avail = false;
            for i = 1:numel( obj.vector_constraints )
                cstr = obj.vector_constraints(i);
                if element == cstr.el_B
                    if cstr.el_B.whichIndex( point_B ) == cstr.B_index ...
                            && cstr.el_A.whichIndex( point_A ) == cstr.A_index ...
                        cstr_avail = true;
                        break
                    end
                end
            end
            % #TODO Implement check on future vector_of_known_constraints
            if ~cstr_avail
                disp( sprintf('B��D DODAWANIA WI�ZU: Para post�powa - kieruj�cy(%d, %d) - brak wi�zu kinematycznego', ...
                obj.index, element.index) );
                return
            end
            u_B= rot( element.fi_c ) * ( ( point_B - point_A ) / norm( point_B - point_A ) );
            my_point_A_index = obj.whichIndex( point_A );
            element_point_B_index = element.whichIndex( point_B );
            % Push to obj.vector_constraints
            obj.vector_constraints = [ obj.vector_constraints ...
                dPrismConstr(obj, my_point_A_index, element, element_point_B_index, u_B, f, f_prim, f_bis) ];
            disp( sprintf('DODANO WI�Z: Para post�powa - kieruj�cy(%d, %d)', ...
                obj.index, element.index) );
        end
        
        % Getting matrices associated with constraints
        function Phi = getPhi(obj)
            % Returns Phi constraints matrix (n x 1) of the element
            Phi = [];
            for i = 1:numel( obj.vector_constraints )
                Phi = [Phi; obj.vector_constraints(i).getConstraint()];
            end
        end
        
        % Misc functions
        function drawElement(obj, color)
            % Draws element.
            % Input:
            %  * color - if not specified methods finds color based on
            %  element's index (obj.index)
            color_arr = ['m' 'y' 'c' 'r' 'g' 'b' 'k'];
            if nargin == 2, element_color = color;
            else
                element_color = color_arr(mod(obj.index, 8) + 1);
            end
            for i=1:size(obj.cell_points, 2)
                % #TODO Might be written better.
                global_point = obj.r_c + rot(obj.fi_c) * cell2mat( obj.cell_points(i) );
                line([obj.r_c(1) global_point(1)], [obj.r_c(2) global_point(2)], ...
                    'Color', element_color);
            end
            p_loc = cell2mat( obj.cell_points );
            boundary_indices = boundary( p_loc(1, :)', p_loc(2, :)' );
            p_glob = rot( obj.fi_c ) * p_loc + obj.r_c * ones(1, numel(p_loc) / 2);
            line( p_glob(1, boundary_indices), p_glob(2, boundary_indices), ...
                    'Color', element_color, 'LineWidth', 3);
        end
        function eraseElement(obj)
            % Erases element from the drawing by drawing
            % the same element with white color - clever, huh?
            % #TODO Not really.. it is suboptimal - it adds new lines to
            % the plot with each call of obj.eraseElement().
            obj.drawElement('w');
        end
        function ind = whichIndex(obj, point)
            % Returns index of given point in cell array of local points
            % (obj.cell_points). If point is not found -1 is returned.
            % Input:
            %  * point - point index of which is to be found
            ind = -1;
            local_point = point - obj.r_c;
            for i=1:size( obj.cell_points, 2)
                if cell2mat(obj.cell_points(i)) == local_point
                    ind = i;
                    break
                end
            end
        end
        function saveSingleSolution(obj)
            % Saves data to obj.solution matrix
            next_solution = [obj.solver.time; obj.r_c; obj.fi_c];
            obj.solution = [obj.solution next_solution];
        end
    end
    
end
