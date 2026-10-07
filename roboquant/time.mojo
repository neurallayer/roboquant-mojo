from morrow import Morrow, TimeZone
from std.os import abort

comptime Timestamp = Float64
comptime Timeline = List[Timestamp]
comptime UTC = TimeZone(0, "UTC")
comptime TIME_MIN = from_iso("1900-01-01")
comptime TIME_MAX = from_iso("2100-01-01")


def timestamp_format(timestamp: Timestamp, format: String = "YYYY-MM-DD HH:mm:ss") -> String:
    """
    Format a timestamp into a human-readable string using the specified format.
    Args:
        timestamp (Timestamp): The timestamp to format.
        format (String): The format string to use for formatting the timestamp.
    Returns:
        String: The formatted timestamp as a string.
    """

    try:
        var dt = Morrow.fromtimestamp(timestamp).astimezone(UTC)
        return dt.format(format)
    except:
        return "Parsing Error {}".format(timestamp)

def from_iso(s: String) -> Float64:
    """
    Convert an ISO format string to a timestamp.
    Args:
        s (String): The ISO format string to convert.
    Returns:
        Float64: The converted timestamp.
    """
    try:
        return Morrow.fromisoformat(s).timestamp()
    except:
        abort(s)

struct Timeframe(ImplicitlyCopyable, Writable):
    """
    Represents a time interval with a start and end timestamp, and an optional inclusive flag.
    The Timeframe struct provides methods to check if a timestamp is within the interval,
    split the interval into smaller intervals, and format the interval for display.
    Attributes:
        start (Timestamp): The starting timestamp of the interval.
        end (Timestamp): The ending timestamp of the interval.
        inclusive (Bool): A flag indicating whether the end timestamp is inclusive.
    """

    comptime INFINITY = Timeframe(TIME_MIN, TIME_MAX)

    var start: Timestamp
    var end: Timestamp
    var inclusive: Bool

    def __init__(out self, start: String, end: String, inclusive: Bool = False):
        self.start = from_iso(start)
        self.end = from_iso(end)
        self.inclusive = inclusive

    def __init__(out self, start: Timestamp, end: Timestamp, inclusive: Bool = False):
        self.start = start
        self.end = end
        self.inclusive = inclusive

    def split(self, n: Int) -> List[Timeframe]:
        """
        Split the Timeframe into n smaller Timeframes of equal duration.
        Args:
            n (Int): The number of smaller Timeframes to create.
        Returns:
            List[Timeframe]: A list of n smaller Timeframes.
        """
        
        var result:  List[Timeframe] = []
        var start = self.start
        var step = (self.end - self.start) / Float64(n)
        for idx in range(n):
            var end = start + step
            if end > self.end:
                end = self.end
            var inclusive = False if idx < n-1 else self.inclusive
            var tf = Timeframe(start, end, inclusive)
            result.append(tf)
            start = end
        return result^

    def __contains__(self, time: Timestamp) -> Bool:
        if self.inclusive:
            return self.start <= time <= self.end
        return self.start <= time < self.end
    
    def write_to(self, mut writer: Some[Writer]):
        var close_str = "]" if self.inclusive else ">"   
        var start = timestamp_format(self.start)
        var end = timestamp_format(self.end)
        writer.write("[", start, " - ", end, close_str)
 