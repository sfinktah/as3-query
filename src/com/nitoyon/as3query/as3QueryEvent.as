package com.nitoyon.as3query {

import flash.display.DisplayObject;
import flash.events.IEventDispatcher;
import flash.events.*;
import flash.utils.Dictionary;
import flash.utils.getDefinitionByName;

internal class as3QueryEvent {
	static private var triggered:Boolean = false;

	// Bind an event to an element
	// Original by Dean Edwards
	static public function add(element:IEventDispatcher, type:String, handler:Function, data:Object):void {
		// if data is passed, bind to handler 
		if( data != null ) { 
			/*// Create unique handler function, wrapped around original handler 
			handler = function(... args):Object { 
				// Pass arguments and context to original handler 
				return handlerOrg.apply(this, args); 
			};*/
			throw new Error("data is not supported currently");
		}

		// Init the element's event structure
		var events:Object = as3Query.data(element, "events") || as3Query.data(element, "events", {});
		
		// Get the current list of functions bound to this event
		var handlers:Dictionary = events[type];

		// Init the event handler queue
		if (!handlers) {
			handlers = events[type] = new Dictionary();

			var handle:Function = ( as3Query.data(element, "handle") ) ? (as3Query.data(element, "handle") as Function ) :
            // au samedi 6 novembre 2010 :
            // un ajout qui corrige un bug lourd dans l'appel des évènements .
            // as3query n'emploie qu'une seule fonction à l'appel de n'importe quel évènement
            // cette fonction met en place un mécanisme de redirection vers les procédures définies
            // par le développeur utilisateur de la lib AS3Query.
            // Dans la lib d'origine, le handle était recréé à chaque enregistrement d'un nouvel évènement (via la méthode bind)
            // ce qui libérait des fuites et empêchait la fermeture d'un évènement (via unbind)
            // 
            as3Query.data(element, "handle", function(... args):Object{
				// returned undefined or false
				var val:Object;

				// Handle the second event of a trigger
				if ( as3QueryEvent.triggered )
					return val;
				
				var event:Event = args.shift() as Event;
				val = as3QueryEvent.handle(element, event, args);
				
				return val;
			}) as Function;

			// And bind the global event handler to the element
			element.addEventListener(type, handle, false);
		}

		// Add the function to the element's handler list
		handlers[handler] = handler;

		// Keep track of which events have been used, for global triggering
		global[type] = true;
	}

	static private var global:Object = {};

	// Detach an event or set of events from an element
	static public function remove(element:IEventDispatcher, type:Object, handler:Function = null):void {
		var events:Object = as3Query.data(element, "events"), ret:Object, index:int;

		if ( events ) {
			// type is actually an event object here
			if ( type is Event ) {
				throw Error("not supported");
				//handler = type.handler;
				//type = type.type;
			}

			if ( !type ) {
				for ( type in events )
					remove( element, type );

			} else if ( events[type.toString()] ) {
				var typeStr:String = type.toString();

				// remove the given handler for the given type
				if ( handler != null )
					delete events[typeStr][handler];

				// remove all handlers for the given type
				else
					for ( var h:* in events[typeStr] )
						// Handle the removal of namespaced events
						delete events[typeStr][h];

				// remove generic event handler if no more handlers exist
				for ( ret in events[typeStr] ) break;
				if ( !ret ) {
					if (element)
						element.removeEventListener(typeStr, as3Query.data(element, "handle") as Function, false);
					ret = null;
					delete events[typeStr];
				}
			}

			// Remove the expando if it's no longer used
			for ( ret in events ) break;
			if ( !ret ) {
				as3Query.removeData( element, "events" );
				as3Query.removeData( element, "handle" );
			}
		}
	}

	static public function trigger(type:String, data:Array, element:IEventDispatcher, donative:Boolean = true, extra:Function = null):Object {
		// Clone the incoming data, if any
		data = as3Query.makeArray(data || []);
		var val:Object;

		// Handle a global trigger
		if ( !element ) {
			// Only trigger if we've ever bound an event for it
			if ( global[type] )
				as3Query.create("*").add([as3Query.stage]).trigger(type, data);

		// Handle triggering a single element
		} else {
			var evt:Boolean = !data[0] || !data[0].preventDefault;

			// Pass along a fake event
			
			// These are some additions to make MouseEvent work (and any other events)
			// If a fully qualified type is passed, eg "flash.events.MouseEvent.CLICK"
			// then it will create:  new flash.events.MouseEvent(flash.events.MouseEvent.CLICK)
			// otherwise, it will just do what it used to, which is create an Event with 
			// a textual type as specified. Something similar needs to be done for
			// event handling (bind) -- sfinktah
			if ( !( data[0] is Event ) ) {
				if (~type.indexOf(".")) {
					var ClassName:String = type.split(".").slice(0, -1).join(".");
					var EventName:String = type.split(".").slice(-1).join(".");
					var ClassReference:Class = getDefinitionByName(ClassName) as Class;
					// var instance:Object = new ClassReference();
					data.unshift( new ClassReference(type) );
				} else {
					// This is the way it was in nitoyons version, only one type of event
					data.unshift( new Event(type) );
				}
			}

			// // Original nitoyon code
			// var event:Event = data[0] as Event;

			// // A test to force a MouseEven (worked) -- sfinktah
			// var event:MouseEvent = data[0] as MouseEvent;

			// Very broad effort to cover all bases -- sfinktah
			var event:* = data[0];

			// I don't understand the rest of this function, but it seems to work -- sfinktah

			// Trigger the event
			if ( as3Query.isFunction( as3Query.data(element, "handle") ) )
				val = (as3Query.data(element, "handle") as Function).apply( element, data );

			// Extra functions don't get the custom event object
			if ( evt )
				data.shift();

			// Handle triggering of extra function
			if ( extra != null && extra.apply( element, data ) === false )
				val = false;

			// Trigger the native events
			if ( donative && val !== false ) {
				triggered = true;
				element.dispatchEvent(event);
			}

			triggered = false;
		}
		return val;
	}

	static public function handle(element:IEventDispatcher, event:Event, args:Array):Object {
		// returned undefined or false
		var val:Object;

		var type:String = event.type;

		var c:Dictionary = (as3Query.data(element, "events") && as3Query.data(element, "events")[type]) as Dictionary;
		args.unshift( event );

		for ( var j:* in c ) {
			// Pass in a reference to the handler function itself
			// So that we can later remove it
			//args[0].handler = c[j];
			//args[0].data = c[j].data;

			// Filter the functions by class
			var tmp:Object = c[j].apply( element, args );

			if ( val !== false )
				val = tmp;

			if ( tmp === false ) {
				event.preventDefault();
				event.stopPropagation();
			}
		}

		return val;
	}
}
}
