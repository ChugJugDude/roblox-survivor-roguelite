--!strict
-- Builds an instance from a property table, setting Parent last:
--     Create("TextLabel", { Text = "Hi", Size = UDim2.fromScale(1, 1), Parent = frame })

return function(className: string, properties: { [string]: any }): any
	local instance = Instance.new(className)
	for key, value in properties do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if properties.Parent then
		instance.Parent = properties.Parent
	end
	return instance
end
