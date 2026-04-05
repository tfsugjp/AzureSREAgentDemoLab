---
applyTo: "**/*.Tests/**/*.cs,**/*Tests.cs"
---

# MSTest Best Practices (MSTest 3.x/4.x)

Your goal is to help me write effective unit tests with modern MSTest, using current APIs and best practices.

## Project Setup

- Use a separate test project with naming convention `[ProjectName].Tests`
- Reference MSTest 3.x+ NuGet packages (includes analyzers)
- Consider using MSTest.Sdk for simplified project setup
- Run tests with `dotnet test`

## Test Class Structure

- Use `[TestClass]` attribute for test classes
- **Seal test classes by default** for performance and design clarity
- Use `[TestMethod]` for test methods (prefer over `[DataTestMethod]`)
- Follow Arrange-Act-Assert (AAA) pattern
- Name tests using pattern `MethodName_Scenario_ExpectedBehavior`

```csharp
[TestClass]
public sealed class CalculatorTests
{
    [TestMethod]
    public void Add_TwoPositiveNumbers_ReturnsSum()
    {
        // Arrange
        var calculator = new Calculator();

        // Act
        var result = calculator.Add(2, 3);

        // Assert
        Assert.AreEqual(5, result);
    }
}
```

## Test Lifecycle

- **Prefer constructors over `[TestInitialize]`** - enables `readonly` fields and follows standard C# patterns
- Use `[TestCleanup]` for cleanup that must run even if test fails

## Modern Assertion APIs

```csharp
Assert.AreEqual(expected, actual);
Assert.IsNull(value);
Assert.IsNotNull(value);
Assert.IsTrue(condition);
Assert.IsFalse(condition);

// Exception testing (prefer over [ExpectedException])
var ex = Assert.Throws<ArgumentException>(() => Method(null));
var ex = await Assert.ThrowsAsync<HttpRequestException>(async () => await client.GetAsync(url));

// Collection assertions
Assert.Contains(expectedItem, collection);
Assert.IsEmpty(collection);
Assert.IsNotEmpty(collection);
Assert.HasCount(5, collection);
```

## Data-Driven Tests

```csharp
[TestMethod]
[DataRow(1, 2, 3)]
[DataRow(0, 0, 0, DisplayName = "Zeros")]
public void Add_ReturnsSum(int a, int b, int expected)
{
    Assert.AreEqual(expected, Calculator.Add(a, b));
}
```

## Common Mistakes to Avoid

```csharp
// ❌ Wrong argument order
Assert.AreEqual(actual, expected);
// ✅ Correct
Assert.AreEqual(expected, actual);

// ❌ Using ExpectedException (obsolete)
[ExpectedException(typeof(ArgumentException))]
// ✅ Use Assert.Throws
Assert.Throws<ArgumentException>(() => Method());
```

## Mocking and Isolation

- Use Moq or NSubstitute for mocking dependencies
- Use interfaces to facilitate mocking
- Mock dependencies to isolate units under test
