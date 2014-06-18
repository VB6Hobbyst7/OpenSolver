from gurobipy import *
import tempfile
tFile = tempfile.gettempdir()
m = Model ('myModel')
m = read(tFile + '\\model.lp')
m.optimize()
path = tFile+ '\\modelsolution.sol'
with open(path,'w') as File:
    File.write(str(m.status)+ '\n')
    if m.status != 3 and m.status != 4 and m.status != 5:
		m.write (path)
		Vars = m.getVars()
		Cons = m.getConstrs()
		with open (tFile + '\\sensitivityData.sol','w') as destFile:
			for i in range(len(Vars)):
				try:
					destFile.write(str(Vars[i].rc)+','+str(Vars[i].SAObjLow)+','+str(Vars[i].SAObjUp)+'\n')
				except: pass
			for j in range(len(Cons)):
				try:
					destFile.write(str(Cons[j].pi)+',' + str(Cons[j].rhs)+','+ str(Cons[j].slack)+ ','  + str(Cons[j].SARHSLow) + ',' + str(Cons[j].SARHSUp) +'\n')
				except: pass