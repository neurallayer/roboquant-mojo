from morrow import Morrow, TimeZone
from std.os import abort
from std.python import Python, PythonObject
from std.python.numpy import copy_to_numpy_array

comptime Timestamp = Float64
comptime Timeline = List[Timestamp]
comptime UTC = TimeZone(0, "UTC")
comptime TIME_MIN = from_iso("1900-01-01")
comptime TIME_MAX = from_iso("2100-01-01")

def now() -> Timestamp:
    try:
        return Morrow.utcnow().timestamp()
    except e:
        abort(String(e))

def same_day(t1: Timestamp, t2: Timestamp, tz: TimeZone = UTC) -> Bool:
    """Check if two timestamps are on the same day given a timezone."""
    try:
        var dt1 = Morrow.fromtimestamp(t1).astimezone(tz)
        var dt2 = Morrow.fromtimestamp(t2).astimezone(tz)
        return dt1.year == dt2.year and dt1.month == dt2.month and dt1.day == dt2.day
    except e:
        print("Error in same_day:", e)
        return False

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

    comptime EMPTY = Timeframe(TIME_MIN, TIME_MIN, False)
    comptime INFINITY = Timeframe(TIME_MIN, TIME_MAX, True)

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
 

struct TimeSeries(Copyable, Writable):
    """
    A TimeSeries represents a series of data points indexed by time.
    It is used to store and manage time-based data, such as financial market data.
    Attributes:
        timeline (Timeline): A list of timestamps representing the time points of the series.
        data: A dictionary of values corresponding to each timestamp in the series.
    """

    var timeline: Timeline
    var data: Dict[String, List[Float64]]

    def __init__(out self, timeline: Timeline, data: Dict[String, List[Float64]]):
        self.timeline = timeline.copy()
        self.data = data.copy()
        var l = len(timeline)
        for data in data.values():
            assert len(data) == l, "different len" 

    @staticmethod
    def univariate(name: String, timeline: Timeline, data: List[Float64]) -> Self:
        """
        Create a univariate TimeSeries, so only a single variable.
        Args:
            name (String): The name of the variable.
            timeline (Timeline): A list of timestamps representing the time points of the series.
            data (List[Float64]): A list of Float64 values corresponding to each timestamp in the series.
        Returns:
            TimeSeries: A univariate TimeSeries instance.
        """
        var values_dict: Dict[String, List[Float64]] = {name: data.copy()}
        return Self(timeline, values_dict)  
  

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

        var values = self.data.get(metric)
        if values is None:
            print("Metric not found in TimeSeries:", metric)
            return  

        var times_np = copy_to_numpy_array(self.timeline).astype('datetime64[s]')
        var values_np = copy_to_numpy_array(values.value())

        ax.plot(times_np, values_np, label=metric)
        
    

