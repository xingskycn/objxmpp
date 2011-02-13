#include <assert.h>
#include <stringprep.h>
#import "XMPPJID.h"

@implementation XMPPJID
@synthesize node;
@synthesize domain;
@synthesize resource;

+ JID
{
	return [[[self alloc] init] autorelease];
}

+ JIDWithString: (OFString*)str
{
	return [[[self alloc] initWithString: str] autorelease];
}

- initWithString: (OFString*)str
{
	self = [super init];

	size_t nodesep, resourcesep;
	nodesep = [str indexOfFirstOccurrenceOfString: @"@"];
	resourcesep = [str indexOfFirstOccurrenceOfString: @"/"];

	if (nodesep == -1)
		[self setNode: @""];
	else
		[self setNode: [str substringFromIndex: 0
					       toIndex: nodesep]];

	if (resourcesep == -1) {
		[self setResource: @""];
		resourcesep = [str length];
	} else
		[self setResource: [str substringFromIndex: resourcesep + 1
						 toIndex: [str length]]];

	[self setDomain: [str substringFromIndex: nodesep + 1
					 toIndex: resourcesep]];

	return self;
}

- (void)setNode: (OFString*)node_
{
	OFString *old = node;
	char *nodepart;

	Stringprep_rc rc;
	if ((rc = stringprep_profile([node_ cString], &nodepart, "Nodeprep", 0))
			!= STRINGPREP_OK) {
		of_log(@"Nodeprep failed: %s", stringprep_strerror(rc));
		assert(0);
	}

	@try {
		node = [[OFString alloc] initWithCString: nodepart];
	} @finally {
		free(nodepart);
	}

	[old release];
}

- (void)setDomain: (OFString*)domain_
{
	OFString *old = domain;
	char *srv;

	Stringprep_rc rc;
	if ((rc = stringprep_profile([domain_ cString], &srv, "Nameprep", 0))
			!= STRINGPREP_OK) {
		of_log(@"Nameprep failed: %s", stringprep_strerror(rc));
		assert(0);
	}

	@try {
		domain = [[OFString alloc] initWithCString: srv];
	} @finally {
		free(srv);
	}

	[old release];
}

- (void)setResource: (OFString*)resource_
{
	OFString *old = resource;
	char *res;

	Stringprep_rc rc;
	if ((rc = stringprep_profile([resource_ cString], &res,
				"Resourceprep", 0)) != STRINGPREP_OK) {
		of_log(@"Resourceprep failed: %s", stringprep_strerror(rc));
		assert(0);
	}

	@try {
		resource = [[OFString alloc] initWithCString: res];
	} @finally {
		free(res);
	}

	[old release];
}

- (OFString*)bareJID
{
	if ([node length])
		return [OFString stringWithFormat: @"%@@%@", node, domain];
	else
		return [OFString stringWithFormat: @"%@", domain];
}

- (OFString*)fullJID
{
	if ([node length])
		return [OFString stringWithFormat: @"%@@%@/%@",
		       node, domain, resource];
	else
		return [OFString stringWithFormat: @"%@/%@",
		       domain, resource];
}
@end
