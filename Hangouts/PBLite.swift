import Foundation

// PBLite Enum Type

class Enum : NSObject, IntegerLiteralConvertible {
	let representation: NSNumber
	required init(value: NSNumber) {
		self.representation = value
	}
	
	convenience override init() {
		self.init(value: -1)
	}
	
	required init(integerLiteral value: IntegerLiteralType) {
		self.representation = value
	}
}

func ==(lhs: Enum, rhs: Enum) -> Bool {
	return lhs.representation == rhs.representation
}

func !=(lhs: Enum, rhs: Enum) -> Bool {
	return !(lhs == rhs)
}

func ~=(pattern: Enum, predicate: Enum) -> Bool {
	return pattern == predicate
}

// PBLite Message Type

class Message : NSObject {
	required override init() { }
	class func isOptional() -> Bool { return false }
	
	func serialize(input: AnyObject?) -> AnyObject? {
		return nil
	}
	
	override var description: String {
		return "message \(self.dynamicType.description())"
	}
	
	override var debugDescription: String {
		let mirror = Mirror(reflecting: self)
		var string = "message \(self.dynamicType.description()) {\n"
		for thing in mirror.children {
			string += "\t\(thing.label!) = \(thing.value);\n"
		}
		return string + "}\n"
	}
}

// PBLiteSerialization wrapper

class PBLiteSerialization {
	
	class func ObjectWithData(data: NSData) throws -> AnyObject {
		return ""
	}
	
	class func dataWithObject(obj: AnyObject) throws -> NSData {
		return NSData()
	}
	
	class func ObjectWithString(data: NSString) throws -> AnyObject {
		return ""
	}
	
	class func stringWithObject(obj: AnyObject) throws -> NSString {
		return ""
	}
	
	/*class func ObjectWithStream(stream: NSInputStream) throws -> AnyObject {
		return ""
	}*/
	
	/*class func writeObject(obj: AnyObject, toStream stream: NSOutputStream) throws -> Int {
		return 0
	}*/
	
	class func isValidObject(obj: AnyObject) -> Bool {
		return true
	}
	
	// ----
	
	// AnyObject?
	class func _unwrapOptionalType(any: Any) -> Any.Type? {
		let dynamicTypeName = "\(Mirror(reflecting: any).subjectType)"
		if dynamicTypeName.contains("Optional<") {
			var containedTypeName = dynamicTypeName.stringByReplacingOccurrencesOfString("Optional<", withString: "")
			containedTypeName = containedTypeName.stringByReplacingOccurrencesOfString(">", withString: "")
			return NSClassFromString(containedTypeName)
		}
		return nil
	}
	
	// [AnyObject]?
	class func _unwrapOptionalArrayType(any: Any) -> Any.Type? {
		let dynamicTypeName = "\(Mirror(reflecting: any).subjectType)"
		
		if dynamicTypeName.contains("Swift.Array") {
			print("Encountered Swift.Array -> \(dynamicTypeName)!")
		}
		
		if dynamicTypeName.contains("Optional<Array") {
			var containedTypeName = dynamicTypeName.stringByReplacingOccurrencesOfString("Optional<", withString: "")
			containedTypeName = containedTypeName.stringByReplacingOccurrencesOfString("Swift.Array<", withString: "")
			containedTypeName = containedTypeName.stringByReplacingOccurrencesOfString("Array<", withString: "")
			containedTypeName = containedTypeName.stringByReplacingOccurrencesOfString(">", withString: "")
			return NSClassFromString(containedTypeName)
		}
		return nil
	}
	
	//  hackety hack, this is extremely brittle but Swift's introspection isn't perfect yet
	// ... etc, one for each different kind of array we might have.
	// This is horrible, but if we can find a function that'll take
	// an Any (really a [Something]) and return Something,
	// this function doesn't need to exist anymore.
	class func getArrayMessageType(arr: Any) -> Message.Type? {
		if arr is [CONVERSATION_ID] { return CONVERSATION_ID.self }
		if arr is [USER_ID] { return USER_ID.self }
		if arr is [CLIENT_EVENT] { return CLIENT_EVENT.self }
		if arr is [CLIENT_ENTITY] { return CLIENT_ENTITY.self }
		if arr is [MESSAGE_SEGMENT] { return MESSAGE_SEGMENT.self }
		if arr is [MESSAGE_ATTACHMENT] { return MESSAGE_ATTACHMENT.self }
		if arr is [CLIENT_CONVERSATION_PARTICIPANT_DATA] { return CLIENT_CONVERSATION_PARTICIPANT_DATA.self }
		if arr is [CLIENT_CONVERSATION_READ_STATE] { return CLIENT_CONVERSATION_READ_STATE.self }
		if arr is [ENTITY_GROUP_ENTITY] { return ENTITY_GROUP_ENTITY.self }
		return nil
	}
	class func getArrayEnumType(arr: Any) -> Enum.Type? {
		if arr is [ConversationView] { return ConversationView.self }
		return nil
	}
	
	//  Hacky, but if we're doing this at runtime, we don't get Swift's nice implicit Convertables.
	class func valueWithTypeCoercion(property: Any, value: AnyObject?) -> AnyObject? {
		if property is NSDate || _unwrapOptionalType(property) is NSDate.Type {
			if let number = value as? NSNumber {
				let timestampAsDate = from_timestamp(number)
				return timestampAsDate
			}
		}
		return value
	}
	
	class func parseProtoJSON<T: Message>(input: NSData) -> T? {
		let script = "a = " + (NSString(data: input, encoding: 4)! as String)
		if let parsedObject = JSContext().evaluateScript(script).toArray() {
			return parseArray(T.self, input: parsedObject)
		}
		return nil
	}
	
	class func parseJSON<T: Message>(input: NSData) -> T? {
		let script = "a = " + (NSString(data: input, encoding: 4)! as String)
		if let parsedObject = JSContext().evaluateScript(script).toDictionary() {
			return parseDictionary(T.self, obj: parsedObject)
		}
		return nil
	}
	
	// Parsing
	
	//  Due to peculiarities in Swift's type system, we need to pass in "type" here.
	class func parseArray<T: Message>(type: T.Type, input: NSArray?) -> T? {
		guard let arr = input else {
			return nil // expected array
		}
		
		let instance = type.init()
		let reflection = Mirror(reflecting: instance)
		let children = Array(reflection.children)
		for var i = 0; i < min(arr.count, children.count); i++ {
			let propertyName = children[i].label!
			let property = children[i].value
			
			//  Unwrapping an optional sub-struct
			if let type = _unwrapOptionalType(property) as? Message.Type {
				let val: (AnyObject?) = parseArray(type, input: arr[i] as? NSArray)
				instance.setValue(val, forKey: propertyName)
				
				//  Using a non-optional sub-struct
			} else if let message = property as? Message {
				let val: (AnyObject?) = parseArray(message.dynamicType, input: arr[i] as? NSArray)
				instance.setValue(val, forKey: propertyName)
				
				//  Unwrapping an optional enum
			} else if let type = _unwrapOptionalType(property) as? Enum.Type {
				let val: (AnyObject?) = type.init(value: (arr[i] as! NSNumber))
				instance.setValue(val, forKey: propertyName)
				
				//  Using a non-optional sub-struct
			} else if let enumv = property as? Enum {
				let val: (AnyObject?) = enumv.dynamicType.init(value: (arr[i] as! NSNumber))
				instance.setValue(val, forKey: propertyName)
				
				// Default
			} else {
				if arr[i] is NSNull {
					instance.setValue(nil, forKey: propertyName)
				} else {
					if let elementType = _unwrapOptionalArrayType(property) {
						let elementMessageType = elementType as! T.Type
						let val = (arr[i] as! NSArray).map {
							parseArray(elementMessageType, input: $0 as? NSArray)!
						}
						instance.setValue(val, forKey:propertyName)
					} else if let elementType = getArrayMessageType(property) {
						let val = (arr[i] as! NSArray).map {
							parseArray(elementType, input: $0 as? NSArray)!
						}
						instance.setValue(val, forKey:propertyName)
					} else if let elementType = getArrayEnumType(property) {
						let val = (arr[i] as! NSArray).map {
							elementType.init(value: ($0 as! NSNumber))
						}
						instance.setValue(val, forKey:propertyName)
					} else {
						instance.setValue(valueWithTypeCoercion(property, value: arr[i]), forKey:propertyName)
					}
				}
			}
		}
		return instance
	}
	
	class func parseDictionary<T: Message>(type: T.Type, obj: NSDictionary) -> T? {
		let instance = type.init()
		let reflection = Mirror(reflecting: instance)
		for child in reflection.children {
			let propertyName = child.label!
			let property = child.value
			
			let value: AnyObject? = obj[propertyName]
			
			//  Unwrapping an optional sub-struct
			if let type = _unwrapOptionalType(property) as? Message.Type {
				let val: (AnyObject?) = parseDictionary(type, obj: value as! NSDictionary)
				instance.setValue(val, forKey: propertyName)
				
				//  Using a non-optional sub-struct
			} else if let message = property as? Message {
				let val: (AnyObject?) = parseDictionary(message.dynamicType, obj: value as! NSDictionary)
				instance.setValue(val, forKey: propertyName)
				
				//  Unwrapping an optional enum
			} else if let type = _unwrapOptionalType(property) as? Enum.Type {
				let val: (AnyObject?) = type.init(value: (value as! NSNumber))
				instance.setValue(val, forKey: propertyName)
				
				//  Using a non-optional sub-struct
			} else if let enumv = property as? Enum {
				let val: (AnyObject?) = enumv.dynamicType.init(value: (value as! NSNumber))
				instance.setValue(val, forKey: propertyName)
				
				// Default
			} else {
				if value is NSNull || value == nil {
					instance.setValue(nil, forKey: propertyName)
				} else {
					if let elementType = getArrayMessageType(property) {
						let val = (value as! NSArray).map {
							parseDictionary(elementType, obj: $0 as! NSDictionary)!
						}
						instance.setValue(val, forKey:propertyName)
					} else if let elementType = getArrayEnumType(property) {
						let val = (value as! NSArray).map {
							elementType.init(value: ($0 as! NSNumber))
						}
						instance.setValue(val, forKey:propertyName)
					} else {
						instance.setValue(valueWithTypeCoercion(property, value: value), forKey: propertyName)
					}
				}
			}
		}
		return instance
	}
}
