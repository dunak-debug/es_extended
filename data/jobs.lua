local Jobs = {
	['unemployed'] = {label = 'Unemployed', grades = {{label = '', name = '', salary = 200}}},

	['police'] = { label = 'Police', grades = {
			{label = 'Recruit', name = 'recruit', salary = 20},
			{label = 'Officer', name = 'officer', salary = 40},
			{label = 'Sergeant', name = 'sergeant', salary = 60},
			{label = 'Lieutenant', name = 'lieutenant', salary = 85},
			{label = 'Chief', name = 'boss', salary = 100},
		}
	},

	['ambulance'] = { label = 'EMS', grades = {
			{label = 'Junior EMT', name = 'ambulance', salary = 20}, 
			{label = 'EMT', name = 'doctor', salary = 40}, 
			{label = 'Senior EMT', name = 'chief_doctor', salary = 60}, 
			{label = 'EMT Supervisor', name = 'boss', salary = 80}, 
		}
	},

	['mechanic'] = { label = 'Mechanic', grades = {
			{label = 'Recruit', name = 'recruit', salary = 12}, 
			{label = 'Novice', name = 'novice', salary = 24}, 
			{label = 'Experienced', name = 'experienced', salary = 36}, 
			{label = 'Leader', name = 'chief', salary = 48}, 
			{label = 'Boss', name = 'boss', salary = 64}, 
		}
	},

}
return Jobs