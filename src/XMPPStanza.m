/*
 * Copyright (c) 2011, Jonathan Schleifer <js@webkeks.org>
 * Copyright (c) 2011, Florian Zeitz <florob@babelmonkeys.de>
 *
 * https://webkeks.org/hg/objxmpp/
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

#import "XMPPStanza.h"

@implementation XMPPStanza
@synthesize from;
@synthesize to;
@synthesize type;
@synthesize ID;

+ stanzaWithName: (OFString*)name
{
	return [[[self alloc] initWithName: name] autorelease];
}

+ stanzaWithName: (OFString*)name
	    type: (OFString*)type_
{
	return [[[self alloc] initWithName: name
				      type: type_] autorelease];
}

+ stanzaWithName: (OFString*)name
	      ID: (OFString*)ID_
{
	return [[[self alloc] initWithName: name
					ID: ID_] autorelease];
}

+ stanzaWithName: (OFString*)name
	    type: (OFString*)type_
	      ID: (OFString*)ID_
{
	return [[[self alloc] initWithName: name
				      type: type_
					ID: ID_] autorelease];
}

+ stanzaWithElement: (OFXMLElement*)elem
{
	return [[[self alloc] initWithElement: elem] autorelease];
}

- initWithName: (OFString*)name_
{
	return [self initWithName: name_
			     type: nil
			       ID: nil];
}

- initWithName: (OFString*)name_
	  type: (OFString*)type_
{
	return [self initWithName: name_
			     type: type_
			       ID: nil];
}

- initWithName: (OFString*)name_
	    ID: (OFString*)ID_
{
	return [self initWithName: name_
			     type: nil
			       ID: ID_];
}

- initWithName: (OFString*)name_
	  type: (OFString*)type_
	    ID: (OFString*)ID_
{
	self = [super initWithName: name_];

	@try {
		if (![name_ isEqual: @"iq"] && ![name_ isEqual: @"message"] &&
		    ![name_ isEqual: @"presence"])
			@throw [OFInvalidArgumentException newWithClass: isa
							       selector: _cmd];

		[self setDefaultNamespace: @"jabber:client"];

		if (type_)
			[self setType: type_];

		if (ID_)
			[self setID: ID_];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- initWithElement: (OFXMLElement*)elem
{
	self = [super initWithName: elem.name
			 namespace: elem.namespace];

	@try {
		OFXMLAttribute *attr;
		OFXMLElement *el;

		for (attr in elem.attributes) {
			if ([attr.name isEqual: @"from"])
				[self setFrom: [attr stringValue]];
			else if ([attr.name isEqual: @"to"])
				[self setTo: [attr stringValue]];
			else if ([attr.name isEqual: @"type"])
				[self setType: [attr stringValue]];
			else if ([attr.name isEqual: @"id"])
				[self setID: [attr stringValue]];
			else
				[self addAttribute: attr];
		}

		for (el in elem.children)
			[self addChild: el];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[from release];
	[to release];
	[type release];
	[ID release];

	[super dealloc];
}

- (void)setFrom: (OFString*)from_
{
	OFString* old = from;
	from = [from_ copy];
	[old release];

	/* FIXME: Remove old attribute! */
	[self addAttributeWithName: @"from"
		       stringValue: from_];
}

- (void)setTo: (OFString*)to_
{
	OFString* old = to;
	to = [to_ copy];
	[old release];

	/* FIXME: Remove old attribute! */
	[self addAttributeWithName: @"to"
		       stringValue: to];
}

- (void)setType: (OFString*)type_
{
	OFString* old = type;
	type = [type_ copy];
	[old release];

	/* FIXME: Remove old attribute! */
	[self addAttributeWithName: @"type"
		       stringValue: type];
}

- (void)setID: (OFString*)ID_
{
	OFString* old = ID;
	ID = [ID_ copy];
	[old release];

	/* FIXME: Remove old attribute! */
	[self addAttributeWithName: @"id"
		       stringValue: ID];
}
@end
