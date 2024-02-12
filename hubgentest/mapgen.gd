extends Node2D

@onready var tileMap = $TileMap
var forestTile = Vector2i(1,1)
var doorWayTile = Vector2i(6,1)

var neighFour = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]

func _ready():
	#Right now I'm just generating square areas for the doorway rooms, but these could be hand crafted later.
	var roomAmount = 20
	# the rooms array is a just a list of coordinates defining the centre of all the rooms.
	var rooms = []
	while rooms.size() < roomAmount:
		#pick a random spot in a range of (-100 to 100, -100 to 100)
		#-100 to 100 is just an arbitrary number right now, but this would ultimately decide the maximum size of the forest
		# the actual width/height of the map in pixels is more, this is in terms of tiles, in this
		#example the tile size of the tilemap is 16x16, so the actual pixel dimensions would be
		#from -1600 to 1600
		var roomCentre = Vector2i(randi_range(-100, 100),randi_range(-100, 100))
		#need to check if the random spot is too close to a preplaced room, this number will need to be fine tuned
		#if there's not enough space to place all the rooms then it's gonna hang (bad)
		var isValid = true
		for i in rooms:
			#if it's closer than 20 tiles to another room then we're just not gonna do anything, and start the while loop over
			#we need to cast to Vector2 to work out this distance between points, for some reason you cant do that with Vector2i
			if Vector2(roomCentre).distance_to(Vector2(i)) < 20:
				isValid = false
				break
		#if it gets through all the rooms and is valid, add it to the room list.
		if isValid:
			rooms.append(roomCentre)
		
	#now we should have the coordinates for as many rooms as we defined with roomAmount
	#first, connect them all together with a minimal spanning tree, I'm using the 
	#A* object because it's a built in graph data structure, but we're not really doing any
	#navigation, just using it to store nodes(rooms) and generate the edges (connections)
	
	var pathWays = find_mst(rooms.duplicate())
	#this function returns an array of vector2 pairs, each pair being the start point and end point of a pathway.

	#now we can add some extra pathways to make it less linear. I'm gonna use delaunay triangulation, and just
	# grab a couple of extra pathways from that
	
	var roomsTriangulated = Geometry2D.triangulate_delaunay(rooms)
	#this returns an array of triangles, 0,1,2 make one triangle, 3,4,5 makes the next etc.
	#need to tidy this up into an array of vector2 pairs like the pathWays array
	var roomEdges = []
	for i in range(0, roomsTriangulated.size(), 3):
		roomEdges.append([rooms[roomsTriangulated[i]],
							rooms[roomsTriangulated[i + 1]]])
		roomEdges.append([rooms[roomsTriangulated[i + 1]],
							rooms[roomsTriangulated[i + 2]]])
		roomEdges.append([rooms[roomsTriangulated[i + 2]],
							rooms[roomsTriangulated[i]]])
	
	#now we have another array of vector2 pairs, we'll just randomly pick a few from them and add
	#the too the pathWays array
	
	for i in roomEdges:
		#this number here is the percentage, 0.15 means that on average 15% of the pathways will be picked.
		if randf() < 0.15:
			#we'll also check to see if this pathway is already in the array
			if !pathWays.has(i):
				pathWays.append(i)
	
	#this is a little messy right now, as there are duplicates pathways, this can be cleaned up though
	
	#so now we have an array that defines the rooms, and an array that defines the connections
	#we just need to feed this information into the tile map, right now we're just adding the
	#walkable ground tiles, adding the wall tiles need to be discussed
	
	#first i'm gonna add the pathways, then put the rooms in
	#the pathways are just a start point and end point, we just connect them in straight lines,
	#but I do have a random walker method to make windy paths
	
	for i in pathWays:
		#the walker method returns a list of points that connect the start to the end of the pathway
		var points = walker(i)
		for j in points:
			tileMap.set_cell(0,j,0,forestTile)
	
	#now the rooms, again just gonna be 15x15 tile squares for this example
	for i in rooms:
		for x in range(-7, 7):
			for y in range(-7, 7):
				tileMap.set_cell(0,i+Vector2i(x,y),0,forestTile)
		tileMap.set_cell(0,i,0,doorWayTile)
		
func find_mst(points):
	var aStarPath = AStar2D.new()
	aStarPath.add_point(aStarPath.get_available_point_id(), points.pop_front())
	while points:
		var minDist = INF
		var minPos = null
		var pos = null
		
		for i in aStarPath.get_point_ids():
			var pos1 = aStarPath.get_point_position(i)
			
			for pos2 in points:
				if pos1.distance_to(pos2) < minDist:
					minDist = pos1.distance_to(pos2)
					minPos = pos2
					pos = pos1
					
		var id = aStarPath.get_available_point_id()
		aStarPath.add_point(id, minPos)
		aStarPath.connect_points(aStarPath.get_closest_point(pos), id)
		points.erase(minPos)
	
	var pathVectors = []
	for i in aStarPath.get_point_ids():
			for c in aStarPath.get_point_connections(i):
				pathVectors.append(	[aStarPath.get_point_position(i), 
									aStarPath.get_point_position(c)])
	
	return pathVectors

func walker(points):
	var start = Vector2(points[0])
	var end = Vector2(points[1])
	var walkerPoints = []
	
	while start != end:
		var weights = []
		var totalWeight = 0
		
		for i in neighFour:
			var weight = (start+Vector2(i)).distance_to(end)
			weights.append((1/exp(weight)))
			totalWeight += (1/exp(weight))
		
		#normalize weights
		for i in weights.size():
			weights[i] = (weights[i]/totalWeight)
		# Generate a random number between 0 and the total weight
		var randomValue = randf()
		# Determine the chosen option based on the weights
		var cumulativeWeight = 0.0
		var direction = Vector2.ZERO
		for i in range(weights.size()):
			cumulativeWeight += weights[i]
			if randomValue < cumulativeWeight:
				direction = Vector2(neighFour[i])
				break
				
		start += direction
		#this part is messy, but it is what defines the width of the pathways, ideally
		#this can be randomized too.
		#added some random width
		var rWidth = randi_range(2,5)
		var rHeight = randi_range(2,5)
		for x in rWidth:
			for y in rHeight:
				walkerPoints.append(start+Vector2(x,y))
				walkerPoints.append(start+Vector2(-x,-y))
	
	return walkerPoints

func _process(delta):
	pass
