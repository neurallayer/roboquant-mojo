from std.os import abort
from std.python import Python, PythonObject
from std.python.numpy import copy_to_numpy_array
from std.logger import Logger
from std.time import time


comptime logger = Logger()

comptime Timeline = List[Timestamp]


struct Timeframe(ImplicitlyCopyable, Writable, TrivialRegisterPassable):
    """
    Represents a time interval with a start and end timestamp, and an optional inclusive flag.
    The Timeframe struct provides methods to check if a timestamp is within the interval,
    split the interval into smaller intervals, and format the interval for display.

    Attrs:
        start: The starting timestamp of the interval.
        end: The ending timestamp of the interval.
        inclusive: A flag indicating whether the end timestamp is inclusive. The start time
            is always inclusive. 
    """

    var start: Timestamp
    var end: Timestamp
    var inclusive: Bool

    def __init__(out self, start: String, end: String, inclusive: Bool = False) raises:
        self.start = Timestamp.from_iso(start)
        self.end = Timestamp.from_iso(end)
        self.inclusive = inclusive

    def __init__(out self, start: Timestamp, end: Timestamp, inclusive: Bool = False):
        self.start = start
        self.end = end
        self.inclusive = inclusive

    @staticmethod
    def empty() -> Self:
        return Timeframe(Timestamp.MIN, Timestamp.MIN, False)

    def split(self, n: Int) -> List[Timeframe]:
        """
        Split the Timeframe into n smaller Timeframes of equal duration.

        Args:
            n: The number of smaller Timeframes to create.

        Returns:
            A list of n smaller Timeframes.
        """

        var result:  List[Timeframe] = List[Timeframe](capacity=n)
        var start = self.start
        var step = (self.end - self.start) / n
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
        var start = self.start.format()
        var end = self.end.format()
        writer.write("[", start, " - ", end, close_str)

struct TimeSeries(Copyable, Writable):
    """
    A TimeSeries represents a series of data points indexed by time.
    It is used to store and manage time-based data, such as financial market data.

    Attributes:
        timeline: A list of timestamps representing the time points of the series.
        data: A dictionary of values corresponding to each timestamp in the series.
    """

    var timeline: Timeline
    var data: Dict[String, List[Float64]]

    def __init__(out self, var timeline: Timeline, var data: Dict[String, List[Float64]]):
        var l = len(timeline)       
        for data in data.values():
            assert len(data) == l, "different len" 

        self.timeline = timeline^
        self.data = data^

    @staticmethod
    def univariate(name: String, var timeline: Timeline, var data: List[Float64]) -> Self:
        """
        Create a univariate TimeSeries, so only a single variable.
        Args:
            name (String): The name of the variable.
            timeline (Timeline): A list of timestamps representing the time points of the series.
            data (List[Float64]): A list of Float64 values corresponding to each timestamp in the series.
        Returns:
            TimeSeries: A univariate TimeSeries instance.
        """
        var values_dict: Dict[String, List[Float64]] = {name: data^}
        return Self(timeline^, values_dict^)  

    @staticmethod
    def univariate(name: String, data: List[Tuple[Timestamp, Float64]]) -> Self:
        """
        Create a univariate TimeSeries, so only a single variable.

        Args:
            name: The name of the variable.
            data: A list of Tuple[Timestamp, Float64] values corresponding to each timestamp in the series.

        Returns:
            A univariate TimeSeries instance.
        """
        var values_dict: Dict[String, List[Float64]] = {name: [v for (_, v) in data]}
        return Self([t for (t, _) in data], values_dict^)  
  

    def plot(self, *metrics: String) raises -> None:
        """
        Plot one or more metrics in a single chart (Axis).
        It requires the matplotlib library and numpy to be installed in the environment.
        """

        var plt = Python.import_module("matplotlib.pyplot")
        var fig_ax = plt.subplots()
        var ax = fig_ax[1]
        for metric in metrics:
            self.plot(metric, ax)
        ax.legend()
        plt.show()

    def plot(self, metric: String, ax: PythonObject) raises -> None:
        """
        Plot the TimeSeries data using a plotting library.
        This method visualizes the time series data for analysis and interpretation.
        """
        if  case .Some(values) = self.data.get(metric):
            var floats = [ts.to_unix_timestamp() for ts in self.timeline]
            var times_np = copy_to_numpy_array(floats).astype('datetime64[s]')
            var values_np = copy_to_numpy_array(values)
            ax.plot(times_np, values_np, label=metric)
        else:
            logger.warning("Metric not found in TimeSeries:", metric)
            return  
        
    def plot(self, ax: PythonObject) raises -> None:
        """
        Plot the TimeSeries data using a plotting library.
        This method visualizes the time series data for analysis and interpretation.
        """
        var floats = [ts.to_unix_timestamp() for ts in self.timeline]
        var times_np = copy_to_numpy_array(floats).astype('datetime64[s]')
        for item in self.data.items():
            ref metric = item.key
            ref values = item.value 
            var values_np = copy_to_numpy_array(values)
            ax.plot(times_np, values_np, label=metric)
    
    
def _pad_zero[I: Intable](value: I, width: Int) -> String:
    """Format `value` with leading zeros up to `width` characters."""
   return String(Int(value)).ascii_rjust(width, "0")


struct UTCDateTime(Copyable, Movable, Writable):
    """Basic date-time object that assumes everything is in UTC timezone."""

    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var minute: Int
    var second: Int
    var nanosecond: Int

    def __init__(
        out self,
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0,
        nanosecond: Int = 0,
    ):
        """Create a UTC datetime, time of day defaults to midnight."""
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.nanosecond = nanosecond

    @staticmethod
    def now() -> Self:
        return Self.from_timestamp(Timestamp(time._realtime_nanoseconds()))

    def same_day(self, other: UTCDateTime, offset: Int = 0) -> Bool:
        return self.year == other.year and self.month == other.month and self.day == other.day

    @staticmethod
    def from_timestamp(t: Timestamp) -> Self:
        return t.to_datetime()

    def timestamp(self) -> Timestamp:
        """Convert this UTC datetime to a Unix timestamp in nanoseconds."""
        var y = self.year - (1 if self.month <= 2 else 0)
        var era = (y if y >= 0 else y - 399) // 400
        var yoe = y - era * 400
        var m = self.month
        var mp = m - 3 if m > 2 else m + 9
        var doy = (153 * mp + 2) // 5 + self.day - 1
        var doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
        var days = era * 146097 + doe - 719468

        var seconds = days * 86400 + self.hour * 3600 + self.minute * 60 + self.second
        return Timestamp(seconds * 1_000_000_000 + self.nanosecond)


    def write_to(self, mut writer: Some[Writer]):
        """Write the datetime in ISO-8601 form: 2024-01-15T12:34:56Z."""
        writer.write(_pad_zero(self.year, 4))
        writer.write("-")
        writer.write(_pad_zero(self.month, 2))
        writer.write("-")
        writer.write(_pad_zero(self.day, 2))
        writer.write("T")
        writer.write(_pad_zero(self.hour, 2))
        writer.write(":")
        writer.write(_pad_zero(self.minute, 2))
        writer.write(":")
        writer.write(_pad_zero(self.second, 2))
        var str_ns = String(Float64(self.nanosecond)/1_000_000_000)[codepoint=1:]
        writer.write(str_ns)
        writer.write("Z")


def _parse_iso_timestamp(s: String) raises -> Timestamp:
    """Parse an ISO-8601 date or datetime string into a Timestamp.

    Supported formats are "2020", "2020-05", "2023-01-01",
    "2023-01-01 12:00", "1999-01-01T12:00:00", and variants with
    fractional seconds ("1999-01-01T12:00:00.250") and/or a
    trailing UTC designator ("1999-01-01T12:00:00Z").
    """
    var text = s.strip()

    # Drop a trailing UTC designator, if present.
    var z_parts = text.split("Z")
    if len(z_parts) > 1:
        text = z_parts[0]

    # Separate the date part from the optional time part.
    var parts = text.split("T")
    if len(parts) == 1:
        parts = text.split(" ")
    var date_part = parts[0]
    var date_args = date_part.split("-")
    var year = Int(date_args[0])
    var month = 1
    var day = 1
    if len(date_args) > 1:
        month = Int(date_args[1])
    if len(date_args) > 2:
        day = Int(date_args[2])

    var hour = 0
    var minute = 0
    var second = 0
    var nanosecond = 0

    if len(parts) > 1:
        var time_part = parts[1] 
        var time_args = time_part.split(":")
        hour = Int(time_args[0])
        if len(time_args) > 1:
            minute = Int(time_args[1])
        if len(time_args) > 2:
            var sec_args = time_args[2].split(".")
            second = Int(sec_args[0])
            if len(sec_args) > 1:
                nanosecond = Int(Float64("0." + sec_args[1]) * 1_000_000_000.0)

    return UTCDateTime(year, month, day, hour, minute, second, nanosecond).timestamp()


struct Timestamp(ImplicitlyCopyable, Comparable, TrivialRegisterPassable, Equatable, Writable, Hashable):
    """A point in time tracked as the number of NANOSECONDS since the epoch (1 Jan 1970 UTC).
    It supports dates before the epoch with a negative value for the number of nanoseconds.
    """

    comptime MIN = Timestamp(-2208988800000000000) # 1900-01-01
    comptime MAX = Timestamp(4102444800000000000) # 2100-01-01

    var nanoseconds: Int

    def __init__(out self, nanoseconds: Int):
        self.nanoseconds = nanoseconds

    def __init__(s: String) raises -> Timestamp:
        """
        Convert an ISO format string to a timestamp.

        Args:
            s: The ISO format string to convert, for example "2020",
                "2023-01-01" or "1999-01-01T12:00:00".

        Returns:
            The converted timestamp.
        """
        return _parse_iso_timestamp(s)

    @staticmethod
    def from_iso(s: String) raises -> Timestamp:
        """
        Convert an ISO format string to a timestamp.

        Args:
            s: The ISO format string to convert, for example "2020",
                "2023-01-01" or "1999-01-01T12:00:00".

        Returns:
            The converted timestamp.
        """
        return _parse_iso_timestamp(s)

    @staticmethod
    def now() -> Timestamp:
        return Timestamp(time._realtime_nanoseconds())

    def __lt__(self, other: Timestamp) -> Bool:
        return self.nanoseconds < other.nanoseconds

    def __lt__(self, other: Timeframe) -> Bool:
        return self < other.start

    def __le__(self, other: Timestamp) -> Bool:
        return self.nanoseconds <= other.nanoseconds

    def __gt__(self, other: Timestamp) -> Bool:
        return self.nanoseconds > other.nanoseconds

    def __gt__(self, other: Timeframe) -> Bool:
        if other.inclusive:
            return self > other.end
        else:
            return self >= other.end

    def __ge__(self, other: Timestamp) -> Bool:
        return self.nanoseconds >= other.nanoseconds

    def __sub__(self, other: Timestamp) -> Int:
        return self.nanoseconds - other.nanoseconds

    def __add__(self, other_ns: Int) -> Timestamp:
        return Timestamp(self.nanoseconds + other_ns)

    def __iadd__(mut self, other_ns: Int):
        self.nanoseconds += other_ns

    def same_day(self,other: Timestamp, offset_minutes:Int = 0) -> Bool:
        """Check if two timestamps are on the same day given the offset."""
        var dt1 = self + offset_minutes * 60_000_000_000 
        var dt2 = other + offset_minutes * 60_000_000_000
        return dt1.to_datetime().same_day(dt2.to_datetime())


    def to_unix_timestamp(self) -> Float64:
        """Convert to a unix timestamp, so the numbers of seconds as a float."""
        return Float64(self.nanoseconds)/1_000_000_000.0 

    @staticmethod
    def __civil_from_days(days: Int) -> Tuple[Int, Int, Int]:
        """Convert days since 1970-01-01 to (year, month, day)."""
        var z = days + 719468
        var era = (z if z >= 0 else z - 146096) // 146097
        var doe = z - era * 146097
        var yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
        var y = yoe + era * 400
        var doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
        var mp = (5 * doy + 2) // 153
        var d = doy - (153 * mp + 2) // 5 + 1
        var m = mp + 3 if mp < 10 else mp - 9
        var year = y + 1 if m <= 2 else y
        return (year, m, d)


    def to_datetime(self) -> UTCDateTime:
        """Convert this timestamp to UTC datetime."""
        # Floor division gives correct behavior for negative (pre-1970) timestamps
        var total_ns = self.nanoseconds
        var total_seconds = total_ns // 1_000_000_000
        var nanosecond = total_ns - total_seconds * 1_000_000_000
        # nanosecond is now in [0, 999_999_999] even for negative total_ns

        var days = total_seconds // 86400
        var sod = total_seconds - days * 86400

        var hour = sod // 3600
        var minute = (sod % 3600) // 60
        var second = sod % 60

        var (year, month, day) = Self.__civil_from_days(days)

        return UTCDateTime(year, month, day, hour, minute, second, nanosecond)

    
    def format(self) -> String:
        """
        Format a timestamp into a human-readable string.

        Returns:
            The formatted timestamp as a string.
        """
        var dt = UTCDateTime.from_timestamp(self)
        return "{}".format(dt)
