/*
 * Copyright (c) 2011, Jonathan Schleifer <js@webkeks.org>
 * Copyright (c) 2011, Florian Zeitz <florob@babelmonkeys.de>
 *
 * https://webkeks.org/git/?p=objxmpp.git
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice is present in all copies.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <assert.h>

#import "XMPPPresence.h"
#import "namespaces.h"

// This provides us with sortable values for show values
static int show_to_int(OFString *show)
{
	if ([show isEqual: @"chat"]) return 0;
	if (show == nil) return 1; // available
	if ([show isEqual: @"away"]) return 2;
	if ([show isEqual: @"dnd"]) return 3;
	if ([show isEqual: @"xa"]) return 4;

	assert(0);
}

@implementation XMPPPresence
+ presence
{
	return [[[self alloc] init] autorelease];
}

+ presenceWithID: (OFString*)ID
{
	return [[[self alloc] initWithID: ID] autorelease];
}

+ presenceWithType: (OFString*)type
{
	return [[[self alloc] initWithType: type] autorelease];
}

+ presenceWithType: (OFString*)type
		ID: (OFString*)ID
{
	return [[[self alloc] initWithType: type
					ID: ID] autorelease];
}

- init
{
	return [self initWithType: nil
			       ID: nil];
}

- initWithID: (OFString*)ID
{
	return [self initWithType: nil
			       ID: ID];
}

- initWithType: (OFString*)type
{
	return [self initWithType: type
			       ID: nil];
}

- initWithType: (OFString*)type
	    ID: (OFString*)ID
{
	return [super initWithName: @"presence"
			      type: type
				ID: ID];
}

- initWithElement: (OFXMLElement*)element
{
	self = [super initWithElement: element];

	@try {
		OFXMLElement *subElement;

		if ((subElement = [element elementForName: @"show"
						namespace: XMPP_NS_CLIENT]))
			[self setShow: [subElement stringValue]];

		if ((subElement = [element elementForName: @"status"
						namespace: XMPP_NS_CLIENT]))
			[self setStatus: [subElement stringValue]];

		if ((subElement = [element elementForName: @"priority"
						namespace: XMPP_NS_CLIENT]))
			[self setPriority:
			    [OFNumber numberWithIntMax:
				[[subElement stringValue] decimalValue]]];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}


- (void)dealloc
{
	[_status release];
	[_show release];
	[_priority release];

	[super dealloc];
}

- (OFString*)type
{
	if (_type == nil)
		return @"available";

	return [[_type copy] autorelease];
}

- (void)setShow: (OFString*)show
{
	OFXMLElement *oldShow = [self elementForName: @"show"
					   namespace: XMPP_NS_CLIENT];

	if (oldShow != nil)
		[self removeChild: oldShow];

	if (show != nil)
		[self addChild: [OFXMLElement elementWithName: @"show"
						    namespace: XMPP_NS_CLIENT
						  stringValue: show]];

	OF_SETTER(_show, show, YES, 1);
}

- (OFString*)show
{
	return [[_show copy] autorelease];
}

- (void)setStatus: (OFString*)status
{
	OFXMLElement *oldStatus = [self elementForName: @"status"
					     namespace: XMPP_NS_CLIENT];

	if (oldStatus != nil)
		[self removeChild: oldStatus];

	if (status != nil)
		[self addChild: [OFXMLElement elementWithName: @"status"
						    namespace: XMPP_NS_CLIENT
						  stringValue: status]];

	OF_SETTER(_status, status, YES, 1);
}

- (OFString*)status
{
	return [[_status copy] autorelease];
}

- (void)setPriority: (OFNumber*)priority
{
	intmax_t prio = [priority intMaxValue];

	if ((prio < -128) || (prio > 127))
		@throw [OFInvalidArgumentException
		    exceptionWithClass: [self class]
			      selector: _cmd];

	OFXMLElement *oldPriority = [self elementForName: @"priority"
					       namespace: XMPP_NS_CLIENT];

	if (oldPriority != nil)
		[self removeChild: oldPriority];

	OFString* priority_s =
	    [OFString stringWithFormat: @"%" @PRId8, [priority int8Value]];
	[self addChild: [OFXMLElement elementWithName: @"priority"
					    namespace: XMPP_NS_CLIENT
					  stringValue: priority_s]];

	OF_SETTER(_priority, priority, YES, 1);
}

- (OFNumber*)priority
{
	return [[_priority copy] autorelease];
}

- (of_comparison_result_t)compare: (id <OFComparing>)object
{
	XMPPPresence *otherPresence;
	OFNumber *otherPriority;
	OFString *otherShow;
	of_comparison_result_t priorityOrder;

	if (object == self)
		return OF_ORDERED_SAME;

	if (![object isKindOfClass: [XMPPPresence class]])
		@throw [OFInvalidArgumentException
		    exceptionWithClass: [self class]
			      selector: _cmd];

	otherPresence = (XMPPPresence*)object;
	otherPriority = [otherPresence priority];
	if (otherPriority == nil)
		otherPriority = [OFNumber numberWithInt8: 0];

	if (_priority != nil)
		priorityOrder = [_priority compare: otherPriority];
	else
		priorityOrder =
		    [[OFNumber numberWithInt8: 0] compare: otherPriority];

	if (priorityOrder != OF_ORDERED_SAME)
		return priorityOrder;

	otherShow = [otherPresence show];
	if ([_show isEqual: otherShow])
		return OF_ORDERED_SAME;

	if (show_to_int(_show) < show_to_int(otherShow))
		return OF_ORDERED_ASCENDING;

	return OF_ORDERED_DESCENDING;
}
@end
