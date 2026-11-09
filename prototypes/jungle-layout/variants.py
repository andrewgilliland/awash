import json, sys, copy
src, out_dir = sys.argv[1], sys.argv[2]
base = json.load(open(src))
J, C = "low_canopy_jungle", "shrinekeeper_camp"
regions = {
    J: {"name": "Low Canopy Jungle", "colour": "#3d6b21", "floor": [0, 2, 1]},
    C: {"name": "Shrinekeeper Camp", "colour": "#7a6a3a", "floor": [0, 2, 1]},
}
def ex(sx, sy, side): return {"screen": [sx, sy], "side": side}
def room(cell, size, region, exits, note, markers=None):
    r = {"note": note, "cell": cell, "size": size, "region": region, "exits": exits}
    if markers: r["markers"] = markers
    return r
N = ["Harbour trail", "Lower terraces", "Canopy walk", "Upper terraces", "Spore Beast's lair", "Shrine steps", "Root hollow"]
variants = {
 "A_ascent": {
  "tidefen_east": ex(5, 0, "east"),
  "rooms": {
   "low_canopy_jungle_1": room([21, 0], [2, 1], J, [ex(0,0,"west"), ex(1,0,"east")], N[0]),
   "low_canopy_jungle_2": room([23, -1], [3, 2], J, [ex(0,1,"west"), ex(2,0,"east"), ex(1,1,"south")], N[1]),
   "low_canopy_jungle_5": room([24, 1], [2, 1], J, [ex(0,0,"north")], N[4]),
   "low_canopy_jungle_3": room([26, -1], [2, 1], J, [ex(0,0,"west"), ex(1,0,"east")], N[2]),
   "low_canopy_jungle_4": room([28, -3], [1, 3], J, [ex(0,2,"west"), ex(0,0,"east")], N[3]),
   "low_canopy_jungle_6": room([29, -3], [2, 1], J, [ex(0,0,"west"), ex(1,0,"east")], N[5]),
   "shrinekeeper_camp_1": room([31, -3], [2, 1], C, [ex(0,0,"west"), ex(1,0,"east")], "Shrinekeeper Camp", {"rest": [0, 0]}),
   "low_canopy_jungle_7": room([33, -3], [1, 3], J, [ex(0,0,"west"), ex(0,2,"east")], N[6]),
  }},
 "B_over_the_village": {
  "tidefen_east": ex(5, 0, "east"),
  "rooms": {
   "low_canopy_jungle_1": room([21, -1], [1, 2], J, [ex(0,1,"west"), ex(0,0,"west")], N[0]),
   "low_canopy_jungle_2": room([18, -1], [3, 1], J, [ex(2,0,"east"), ex(0,0,"north"), ex(0,0,"west")], N[1]),
   "low_canopy_jungle_5": room([16, -1], [2, 1], J, [ex(1,0,"east")], N[4]),
   "low_canopy_jungle_4": room([18, -3], [1, 2], J, [ex(0,1,"south"), ex(0,0,"east")], N[3]),
   "low_canopy_jungle_3": room([19, -3], [3, 1], J, [ex(0,0,"west"), ex(2,0,"east")], N[2]),
   "low_canopy_jungle_6": room([22, -3], [2, 1], J, [ex(0,0,"west"), ex(1,0,"east")], N[5]),
   "shrinekeeper_camp_1": room([24, -3], [2, 1], C, [ex(0,0,"west"), ex(1,0,"east")], "Shrinekeeper Camp", {"rest": [0, 0]}),
   "low_canopy_jungle_7": room([26, -3], [1, 3], J, [ex(0,0,"west"), ex(0,2,"east")], N[6]),
  }},
 "C_low_then_high": {
  "tidefen_east": ex(5, 0, "east"),
  "rooms": {
   "low_canopy_jungle_1": room([21, 0], [2, 1], J, [ex(0,0,"west"), ex(1,0,"east")], N[0]),
   "low_canopy_jungle_2": room([23, 0], [3, 1], J, [ex(0,0,"west"), ex(2,0,"east"), ex(1,0,"south")], N[1]),
   "low_canopy_jungle_5": room([24, 1], [2, 1], J, [ex(0,0,"north")], N[4]),
   "low_canopy_jungle_4": room([26, -2], [1, 3], J, [ex(0,2,"west"), ex(0,0,"east")], N[3]),
   "low_canopy_jungle_3": room([27, -2], [3, 1], J, [ex(0,0,"west"), ex(2,0,"east")], N[2]),
   "low_canopy_jungle_6": room([30, -2], [2, 1], J, [ex(0,0,"west"), ex(1,0,"east")], N[5]),
   "shrinekeeper_camp_1": room([32, -2], [2, 1], C, [ex(0,0,"west"), ex(1,0,"east")], "Shrinekeeper Camp", {"rest": [0, 0]}),
   "low_canopy_jungle_7": room([34, -2], [1, 3], J, [ex(0,0,"west"), ex(0,2,"east")], N[6]),
  }},
}
name = sys.argv[3]
v = variants[name]
w = copy.deepcopy(base)
w["regions"].update(regions)
t = w["rooms"]["tidefen_village_1"]
t["plan"] = {"exits": t["exits"] + [v["tidefen_east"]]}
w["rooms"].update(v["rooms"])
json.dump(w, open(out_dir, "w"), indent=2)
