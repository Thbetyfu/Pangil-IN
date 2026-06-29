from typing import Dict, List, Any

class StreetGraph:
    def __init__(self):
        # Graph nodes represent major intersections.
        # Edges represent roads with weights (travel cost in minutes) and attributes like traffic level & one-way status.
        self.graph = {
            "simpang_dago": {
                "dago_bawah": {"weight": 2.0, "one_way": False},
                "dago_atas": {"weight": 3.0, "one_way": False},
                "dipatiukur": {"weight": 1.5, "one_way": False},
                "siliwangi": {"weight": 2.0, "one_way": True} # one way from dago to siliwangi
            },
            "dago_bawah": {
                "simpang_dago": {"weight": 2.0, "one_way": False},
                "flyover_pasupati": {"weight": 2.5, "one_way": False},
                "merdeka": {"weight": 3.5, "one_way": True} # one way south to merdeka
            },
            "dago_atas": {
                "simpang_dago": {"weight": 3.0, "one_way": False}
            },
            "dipatiukur": {
                "simpang_dago": {"weight": 1.5, "one_way": False},
                "flyover_pasupati": {"weight": 3.0, "one_way": True}
            },
            "siliwangi": {
                "cihampelas": {"weight": 2.0, "one_way": False}
            },
            "cihampelas": {
                "siliwangi": {"weight": 2.0, "one_way": False},
                "flyover_pasupati": {"weight": 2.5, "one_way": True}
            },
            "flyover_pasupati": {
                "dago_bawah": {"weight": 2.5, "one_way": False}
            },
            "merdeka": {
                "dago_bawah": {"weight": 3.5, "one_way": False} # blocked by one-way, but represented
            }
        }

    def predict_escape_routes(self, start_node: str, heading_node: str, max_minutes: float = 5.0) -> List[Dict[str, Any]]:
        """
        Calculates all viable escape routes starting from a location in a specific heading direction
        within a maximum time constraint (minutes).
        """
        if start_node not in self.graph or heading_node not in self.graph:
            return []

        # Validate edge exists
        if heading_node not in self.graph[start_node]:
            return []

        results = []
        
        # Traverse paths using DFS to find all valid escape trajectories
        initial_path = [start_node, heading_node]
        initial_cost = self.graph[start_node][heading_node]["weight"]
        
        self._dfs_search(heading_node, initial_cost, initial_path, max_minutes, results)
        
        # Sort results by travel cost/time ascending
        results.sort(key=lambda x: x["total_time_minutes"])
        return results

    def _dfs_search(self, current_node: str, current_cost: float, path: List[str], max_cost: float, results: List[Dict[str, Any]]):
        # Store path if it has at least 2 nodes
        if len(path) >= 2:
            results.append({
                "path": list(path),
                "total_time_minutes": current_cost,
                "confidence_score": max(0.1, round(1.0 - (current_cost / (max_cost * 1.5)), 2))
            })

        # Base case
        if current_cost >= max_cost:
            return

        # Explore neighbors
        neighbors = self.graph.get(current_node, {})
        for neighbor, edge_info in neighbors.items():
            # Avoid cycles
            if neighbor in path:
                continue

            # Respect one-way streets (cannot traverse backwards on one-way)
            # If the neighbor connects to current_node as one-way and we are trying to go opposite, check graph rules.
            # Here, the graph adjacency is directional. So if B is not in A's adj list, it's not traversable.
            
            travel_time = edge_info["weight"]
            new_cost = current_cost + travel_time
            
            if new_cost <= max_cost * 1.2: # Allow small buffer above limit
                path.append(neighbor)
                self._dfs_search(neighbor, new_cost, path, max_cost, results)
                path.pop()

street_graph = StreetGraph()
