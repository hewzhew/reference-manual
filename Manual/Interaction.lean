/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/

import VersoManual

import Manual.Meta

open Lean.MessageSeverity

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option pp.rawOnError true

#doc (Manual) "与 Lean 交互" =>
%%%
htmlSplit := .never
tag := "interaction"
file := "Interaction"
%%%

Lean 旨在用于交互式操作，而非批处理系统，它不是那种将整个文件输入后再统一转换为目标代码或错误信息的工具。
许多为交互式使用而设计的编程语言都提供了一个{deftech}[REPL]，{margin}[是{noVale "Vale can't handle partly-bolded words"}[“*R*ead-*E*val-*P*rint *L*oop”（读取-求值-打印循环）]的缩写，因为代码被解析（“读取”）、求值，然后显示结果，这个过程可以根据需要重复多次。]用户可以在此输入和测试代码，并使用命令加载源文件、检查项的类型或查询环境。
Lean 的交互特性基于一种不同的范式。
Lean 不是在程序之外提供一个单独的命令提示符，而是在源文件的上下文中提供了完成相同任务的{tech key := "commands"}[命令]。
按照惯例，旨在用于交互式使用而非作为持久代码一部分的命令都以 {keyword}`#` 为前缀。

来自 Lean 命令的信息可在{deftech key := "message log"}_消息日志_中找到，它会累积来自{tech key := "elaborator"}[繁饰器]的输出。
消息日志中的每个条目都与一个特定的源码范围相关联，并有一个{deftech key := "severity"}_严重性_级别。
严重性分为三个级别：{lean type:="Lean.MessageSeverity"}`information`（信息）用于不表示问题的消息，{lean type:="Lean.MessageSeverity"}`warning`（警告）表示潜在问题，{lean type:="Lean.MessageSeverity"}`error`（错误）表示明确的问题。
对于交互式命令，结果通常以信息消息的形式返回，这些消息与命令开头的关键字相关。

# 对项求值
%%%
tag := "hash-eval"
%%%

{keywordOf Lean.Parser.Command.eval}`#eval` 命令用于将代码作为程序运行。
具体来说，它能够执行 {lean}`IO` 动作，采用传值调用（call-by-value）的求值策略，{ref "partial-unsafe"}[{keyword}`partial` 函数会被执行]，并且类型和证明都会被擦除。
若要使用作为{tech key := "definitional equality"}[定义性等价]一部分的归约规则来归约项，请改用 {keywordOf Lean.reduceCmd}`#reduce`。

:::syntax command (title := "对项求值")

```grammar
#eval $t
```

```grammar
#eval! $t
```

{includeDocstring Lean.Parser.Command.eval}

:::

{keywordOf Lean.Parser.Command.eval}`#eval` 总是对提供的项进行{tech key:="elaborator"}[繁饰]和编译。
然后它会检查该项是否间接依赖于任何 {lean}`sorry` 的使用，如果确实依赖，那么除非你用的命令是 {keywordOf Lean.Parser.Command.eval}`#eval!` ，否则求值过程将被终止。
这是因为编译后的代码可能依赖于编译时的一些不变量（例如数组查找不会越界），这些不变量通过适当命题的证明来保证，而运行包含不完整证明（或使用 {lean}`sorry`“证明”了不正确命题）的代码可能会导致 Lean 本身崩溃。

```lean (show := false)
section
variable (m : Type → Type)
open Lean.Elab.Command (CommandElabM)
```

:::paragraph

代码的运行方式取决于其类型：

 * 如果类型在 {lean}`IO` monad 中，它将在一个{tech key := "standard output"}[标准输出]和{tech key := "standard error"}[标准错误]被捕获并重定向到 Lean {tech key := "message log"}[消息日志]的上下文中执行。
   如果返回值的类型不是 {lean}`Unit`，那么其显示效果将与非 monad 表达式的结果无异。
 * 如果类型在 Lean 内部的元编程 monad 之一（{name Lean.Elab.Command.CommandElabM}`CommandElabM`、{name Lean.Elab.Term.TermElabM}`TermElabM`、{name Lean.MetaM}`MetaM` 或 {name Lean.CoreM}`CoreM`）中，则它会在当前上下文中运行。
    例如，在执行 {keywordOf Lean.Parser.Command.eval}`#eval` 命令时，其所处的环境会包含所有在该位置可用的定义（即作用域内的定义）。
    与 {name}`IO` 类似，结果值会像非 monad 表达式的结果一样显示出来。
    当 Lean 在 {ref "lake"}[Lake] 下运行时，其工作目录（以及 {name}`IO` 动作的工作目录）是当前的{tech key := "workspace"}`workspace`。
 * 如果该类型属于其他的 monad {lean}`m` ，并且存在一个 {lean}`MonadLiftT m CommandElabM` 或 {lean}`MonadEvalT m CommandElabM` 实例，那么系统就会使用 {name}`MonadLiftT.monadLift` 或 {name}`MonadEvalT.monadEval` 将该 monad 转换为一个可以用 {keywordOf Lean.Parser.Command.eval}`#eval` 运行的 monad，然后照常运行。
 * 如果项的类型不属于任何受支持的 monad ，那么它将被视为一个纯值。
  系统会运行其编译后的代码，并显示结果。

在对 {keywordOf Lean.Parser.Command.eval}`#eval` 中的项进行繁饰时，所产生的任何辅助定义或其他对环境的修改，都将被丢弃。
然而，如果该项是一个元编程 monad 中的操作，那么通过运行该 monad 操作对环境所做的更改则会被保留。
:::

```lean (show := false)
end
```

如果存在 {name Lean.ToExpr}`ToExpr`、{name}`ToString` 或 {name}`Repr` 实例，结果将使用它们来展示。
如果没有，并且 {option}`eval.derive.repr` 为 {lean}`true`，Lean 会尝试推导一个合适的 {name}`Repr` 实例。
如果找不到或无法推导出合适的实例，则会报错。
将 {option}`eval.pp` 设置为 {lean}`false` 会禁用 {keywordOf Lean.Parser.Command.eval}`#eval` 对 {name Lean.ToExpr}`ToExpr` 实例的使用。

:::example "显示输出"

{keywordOf Lean.Parser.Command.eval}`#eval` 无法显示函数：
```lean (name := funEval) (error := true)
#eval fun x => x + 1
```
```leanOutput funEval
could not synthesize a 'ToExpr', 'Repr', or 'ToString' instance for type
  Nat → Nat
```

即便某个输出类型没有提供现成的 {name}`ToString` 或 {name}`Repr` 实例，它也能够为其推导出一种表示方法：

```lean (name := quadEval)
inductive Quadrant where
  | nw | sw | se | ne

#eval Quadrant.nw
```
```leanOutput quadEval
Quadrant.nw
```

推导出的实例不会被保存。
禁用 {option}`eval.derive.repr` 会导致 {keywordOf Lean.Parser.Command.eval}`#eval` 失败：

```lean (name := quadEval2) (error := true)
set_option eval.derive.repr false
#eval Quadrant.nw
```
```leanOutput quadEval2
could not synthesize a 'ToExpr', 'Repr', or 'ToString' instance for type
  Quadrant
```

:::

{optionDocs eval.pp}

{optionDocs eval.type}

{optionDocs eval.derive.repr}

通过定义一个合适的 {lean}`MonadLift`{margin}[{lean}`MonadLift` 在{ref "lifting-monads"}[“提升 monad”一节]中有描述。]或 {lean}`MonadEval` 实例，可以使 Monad 具备在 {keywordOf Lean.Parser.Command.eval}`#eval` 中执行的能力。
正如 {name}`MonadLiftT` 是 {name}`MonadLift` 实例的传递闭包一样，{name}`MonadEvalT` 是 {name}`MonadEval` 实例的传递闭包。
与 {name}`MonadLiftT` 类似，用户不应该直接为 {name}`MonadEvalT` 定义额外的实例。

{docstring MonadEval}

{docstring MonadEvalT}

# 归约项
%%%
tag := "hash-reduce"
%%%

{keywordOf Lean.reduceCmd}`#reduce` 命令会重复对一个项应用归约，直到其无法再被进一步归约为止。
归约操作会深入到绑定符内部进行，但为了避免意外的性能下降，除非在 {keywordOf Lean.reduceCmd}`#reduce` 命令中启用了相应的选项，不然证明和类型默认会被跳过，。
与 {keywordOf Lean.Parser.Command.eval}`#eval` 命令不同，归约过程不能有副作用，并且其结果会以一个项的形式显示，而非通过 {name}`ToString` 或 {name}`Repr` 实例来展示。
一般来说，{keywordOf Lean.reduceCmd}`#reduce` 主要用于诊断定义性相等和证明项的问题，而 {keywordOf Lean.Parser.Command.eval}`#eval` 更适合用来计算一个项的值。
特别是，使用{tech key := "well-founded recursion"}[良基递归]或作为{tech key := "partial fixpoints"}[部分不动点]定义的函数，用归约引擎来计算会非常缓慢，甚至根本不会进行归约。

:::syntax command (title := "归约项")
```grammar
#reduce $[(proofs := true)]? $[(types := true)]? $t
```

{includeDocstring Lean.reduceCmd}

:::

:::example "归约函数"

归约一个项会得到它在 Lean 逻辑中的范式。
因为底层的项被归约后会直接显示出来，所以不需要 {name}`ToString` 或 {name}`Repr` 实例。
函数也能像其他任何项一样显示出来。

在某些情况下，这个范式很短，并且与人们手写的项很相似：
```lean (name := plusOne)
#reduce (fun x => x + 1)
```
```leanOutput plusOne
fun x => x.succ
```

在其他情况下，则会揭示出诸如加法这类函数在{ref "elab-as-course-of-values"}[繁饰]为 Lean 核心逻辑时的底层实现细节：
```lean (name := onePlus)
#reduce (fun x => 1 + x)
```
```leanOutput onePlus
fun x => (Nat.rec ⟨fun x => x, PUnit.unit⟩ (fun n n_ih => ⟨fun x => (n_ih.1 x).succ, n_ih⟩) x).1 1
```

:::

# 检查类型
%%%
tag := "hash-check"
%%%

:::syntax command (title := "检查类型")

{keyword}`#check` 可用于繁饰一个项并检查其类型。

```grammar
#check $t
```

如果提供的项是一个全局常量的名称标识符，那么 {keyword}`#check` 会打印其类型签名。
否则会先将其视为 Lean 项进行繁饰，然后打印出推导出的类型。
:::

对 {keywordOf Lean.Parser.Command.check}`#check` 中的项进行繁饰时，并不要求该项被完全繁饰：它可能包含元变量。
只要所写的项在理论上可能有一个类型，繁饰就会成功。
如果一个必需的实例永远无法被合成，那么繁饰就会失败；但仅由存在元变量引起的合成问题不会阻碍繁饰。


:::example "{keyword}`#check` 和未确定的类型"
在这个例子中，列表元素的类型并未被确定，所以其类型中包含一个元变量：
```lean (name := singletonList)
#check fun x => [x]
```
```leanOutput singletonList
fun x => [x] : ?m.9 → List ?m.9
```

在这个例子中，由于 {name}`HAdd` 允许不同类型的项相加，因此相加项的类型和加法结果的类型都是未知的。
在幕后，一个元变量代表着那个未知的 {name}`HAdd` 实例。
```lean (name := polyPlus)
#check fun x => x + x
```
```leanOutput polyPlus
fun x => x + x : (x : ?m.12) → ?m.19 x
```

:::

:::syntax command (title := "测试类型错误")
```grammar
#check_failure $t
```
这个命令作为 {keywordOf Lean.Parser.Command.check}`#check` 的变体使用与 {keywordOf Lean.Parser.Command.check}`#check` 相同的过程来繁饰该项。
如果繁饰成功，该命令会报告一个错误；如果繁饰失败，该命令则执行成功，不产生任何错误。
部分繁饰的项以及任何已发现的类型信息都会被添加到{tech key := "message log"}[消息日志]中。
:::


:::example "检查类型错误"

如下方代码所示，尝试将一个字符串与一个自然数相加会失败，这符合预期：
```lean (name := oneOne)
#check_failure "one" + 1
```
```leanOutput oneOne
failed to synthesize
  HAdd String Nat ?m.32

Additional diagnostic information may be available using the `set_option diagnostics true` command.
```
尽管如此，我们仍然可以得到一个部分繁饰的项：
```leanOutput oneOne
"one" + 1 : ?m.32
```

:::

# 合成实例
%%%
tag := "hash-synth"
%%%

:::syntax command (title := "合成实例")
```grammar
#synth $t
```

{keywordOf Lean.Parser.Command.synth}`#synth` 命令尝试为提供的类合成一个实例。
如果成功，则输出结果实例项。

:::

# 查询上下文
%%%
tag := "hash-print"
%%%

{keyword}`#print` 系列命令用于向 Lean 查询有关定义的信息。

:::syntax command (title := "打印定义")
```grammar
#print $t:ident
```

打印一个常量的定义。
:::

使用 {keywordOf Lean.Parser.Command.print}`#print` 打印定义时，会将该定义作为一个项打印出来。
使用{ref "tactics"}[策略]证明的定理，在作为项打印出来时可能会非常庞大。

:::syntax command (title := "打印字符串")
```grammar
#print $s:str
```

将字符串字面量添加到 Lean 的{tech key := "message log"}[消息日志]中。
:::


:::syntax command (title := "打印公理")
```grammar
#print axioms $t
```

列出该常量传递性依赖的所有公理。
:::

:::example "打印公理"

下面这两个函数都用于交换一对比特向量中的元素：

```lean
def swap (x y : BitVec 32) : BitVec 32 × BitVec 32 :=
  (y, x)

def swap' (x y : BitVec 32) : BitVec 32 × BitVec 32 :=
  let x := x ^^^ y
  let y := x ^^^ y
  let x := x ^^^ y
  (x, y)
```

可以使用{ref "function-extensionality"}[函数外延性]、{ref "the-simplifier"}[化简器]和 {tactic}`bv_decide` 来证明它们相等：
```lean
theorem swap_eq_swap' : swap = swap' := by
  funext x y
  simp only [swap, swap', Prod.mk.injEq]
  bv_decide
```

其最终生成的证明使用了一些公理：
```lean (name := axioms)
#print axioms swap_eq_swap'
```
```leanOutput axioms
'swap_eq_swap'' depends on axioms: [propext, Classical.choice, Lean.ofReduceBool, Quot.sound]
```
:::

:::syntax command (title := "打印等式")
命令 {keywordOf Lean.Parser.Command.printEqns}`#print equations`（可缩写为 {keywordOf Lean.Parser.Command.printEqns}`#print eqns`）用于显示一个函数的{tech key := "equational lemmas"}[等式引理]。
```grammar
#print equations $t
```
```grammar
#print eqns $t
```
:::

:::example "打印等式"

```lean (name := intersperse_eqns)
def intersperse (x : α) : List α → List α
  | y :: z :: zs => y :: x :: intersperse x (z :: zs)
  | xs => xs

#print equations intersperse
```
```leanOutput intersperse_eqns
equations:
theorem intersperse.eq_1.{u_1} : ∀ {α : Type u_1} (x y z : α) (zs : List α),
  intersperse x (y :: z :: zs) = y :: x :: intersperse x (z :: zs)
theorem intersperse.eq_2.{u_1} : ∀ {α : Type u_1} (x : α) (x_1 : List α),
  (∀ (y z : α) (zs : List α), x_1 = y :: z :: zs → False) → intersperse x x_1 = x_1
```

它不会打印定义性等式，也不会打印展开等式：
```lean (name := intersperse_eq_def)
#check intersperse.eq_def
```
```leanOutput intersperse_eq_def
intersperse.eq_def.{u_1} {α : Type u_1} (x : α) (x✝ : List α) :
  intersperse x x✝ =
    match x✝ with
    | y :: z :: zs => y :: x :: intersperse x (z :: zs)
    | xs => xs
```

```lean (name := intersperse_eq_unfold)
#check intersperse.eq_unfold
```
```leanOutput intersperse_eq_unfold
intersperse.eq_unfold.{u_1} :
  @intersperse = fun {α} x x_1 =>
    match x_1 with
    | y :: z :: zs => y :: x :: intersperse x (z :: zs)
    | xs => xs
```

:::

:::syntax command (title := "作用域信息")

{includeDocstring Lean.Parser.Command.where}

```grammar
#where
```
:::

:::example "作用域信息"
{keywordOf Lean.Parser.Command.where}`#where` 命令显示了对当前{tech key := "section scopes"}[区域作用域]所做的所有修改，包括在当前作用域以及其嵌套的父作用域中所做的修改。

```lean (fresh := true) (name := scopeInfo)
section
open Nat

namespace A
variable (n : Nat)
namespace B

open List
set_option pp.funBinderTypes true

#where

end A.B
end
```
```leanOutput scopeInfo
namespace A.B

open Nat List

variable (n : Nat)

set_option pp.funBinderTypes true
```

:::

:::syntax command (title := "检查 Lean 版本")

{includeDocstring Lean.Parser.Command.version}

```grammar
#version
```
:::


# 使用 {keyword}`#guard_msgs` 测试输出
%%%
tag := "hash-guard_msgs"
%%%

{keywordOf Lean.guardMsgsCmd}`#guard_msgs` 命令可用于确保一个命令所输出的消息与预期完全一致。
将它与本节介绍的交互式命令结合使用，可以构建出一个只有在输出符合预期时才能成功繁饰的文件；这样的文件可以在 {ref "lake"}[Lake] 中用作{tech key := "test driver"}[测试驱动程序]。

:::syntax command (title := "记录预期输出")
```grammar
$[$_:docComment]?
#guard_msgs $[($_,*)]? in
$c:command
```

{includeDocstring Lean.guardMsgsCmd}

:::

:::example "测试返回值"

{keywordOf Lean.guardMsgsCmd}`#guard_msgs` 命令可以确保一组测试用例通过：

````lean
def reverse : List α → List α := helper []
where
  helper acc
    | [] => acc
    | x :: xs => helper (x :: acc) xs

/-- info: [] -/
#guard_msgs in
#eval reverse ([] : List Nat)

/-- info: ['c', 'b', 'a'] -/
#guard_msgs in
#eval reverse "abc".toList
````

:::


:::paragraph
{keywordOf Lean.guardMsgsCmd}`#guard_msgs` 命令的行为可以通过三种方式指定：

 1. 提供一个过滤器，用以选择要检查的消息子集

 2. 指定一个空白字符的比较策略

 3. 决定是按消息内容排序还是按消息产生的顺序排序

这些配置选项写在括号内，并用逗号分隔。
:::

::::syntax Lean.guardMsgsSpecElt (title := "指定 {keyword}`#guard_msgs` 行为") (open := false)

```grammar
$_:guardMsgsFilter
```
```grammar
whitespace := $_
```
```grammar
ordering := $_
```

{keywordOf Lean.guardMsgsCmd}`#guard_msgs` 有三种选项：过滤器、空白字符比较策略和排序方式。
::::

:::syntax Lean.guardMsgsFilter (title := "{keyword}`#guard_msgs` 的输出过滤器") (open := false)
```grammar
$[drop]? all
```
```grammar
$[drop]? info
```
```grammar
$[drop]? warning
```
```grammar
$[drop]? error
```

{includeDocstring Lean.guardMsgsFilter}

:::


:::syntax Lean.guardMsgsWhitespaceArg (title := "为 `#guard_msgs` 指定空白字符比较") (open := false)
```grammar
exact
```
```grammar
lax
```
```grammar
normalized
```


在比较消息时，开头和结尾的空白字符总是会被忽略。在此基础上，还有以下设置可用：

 * `whitespace := exact` 要求空白字符完全精确匹配。

 * `whitespace := normalized` 会在匹配前将所有换行符转换为空格（这是默认设置）。这允许将预期输出中的长行断开。

 * `whitespace := lax` 会在匹配前将连续的空白字符折叠成一个空格。

:::

当预期消息与实际产生的消息不匹配时，选项 {option}`guard_msgs.diff` 控制着{keywordOf Lean.guardMsgsCmd}`#guard_msgs` 产生的错误消息内容。
默认情况下，错误消息会显示实际产生的消息，用户可以将其与源文件中的预期消息进行比较。
当消息很长且差异很小时，可能很难发现不同之处。
将 {option}`guard_msgs.diff` 设置为 `true` 会使 {keywordOf Lean.guardMsgsCmd}`#guard_msgs` 转而显示逐行差异，用开头的 `+` 用于指示来自实际产生消息的行，用开头的 `-` 用于指示来自预期消息的行。

{optionDocs guard_msgs.diff}

:::example "显示差异"
{keywordOf Lean.guardMsgsCmd}`#guard_msgs` 命令可用于测试玫瑰树 {lean}`Tree` 的定义以及创建它们的函数 {lean}`Tree.big`：

```lean
inductive Tree (α : Type u) : Type u where
  | val : α → Tree α
  | branches : List (Tree α) → Tree α

def Tree.big (n : Nat) : Tree Nat :=
  if n = 0 then .val 0
  else if n = 1 then .branches [.big 0]
  else .branches [.big (n / 2), .big (n / 3)]
```

然而，当输出很大时，很难发现测试失败的来源：
```lean (error := true) (name := bigMsg)
/--
info: Tree.branches
  [Tree.branches
     [Tree.branches [Tree.branches [Tree.branches [Tree.val 0], Tree.val 0], Tree.branches [Tree.val 0]],
      Tree.branches [Tree.branches [Tree.val 2], Tree.branches [Tree.val 0]]],
   Tree.branches
     [Tree.branches [Tree.branches [Tree.val 0], Tree.branches [Tree.val 0]],
      Tree.branches [Tree.branches [Tree.val 0], Tree.val 0]]]
-/
#guard_msgs in
#eval Tree.big 20
```
求值产生：
```leanOutput bigMsg (severity := information)
Tree.branches
  [Tree.branches
     [Tree.branches [Tree.branches [Tree.branches [Tree.val 0], Tree.val 0], Tree.branches [Tree.val 0]],
      Tree.branches [Tree.branches [Tree.val 0], Tree.branches [Tree.val 0]]],
   Tree.branches
     [Tree.branches [Tree.branches [Tree.val 0], Tree.branches [Tree.val 0]],
      Tree.branches [Tree.branches [Tree.val 0], Tree.val 0]]]
```

而 {keywordOf Lean.guardMsgsCmd}`#guard_msgs` 命令报告此错误：
```leanOutput bigMsg (severity := error)
❌️ Docstring on `#guard_msgs` does not match generated message:

info: Tree.branches
  [Tree.branches
     [Tree.branches [Tree.branches [Tree.branches [Tree.val 0], Tree.val 0], Tree.branches [Tree.val 0]],
      Tree.branches [Tree.branches [Tree.val 0], Tree.branches [Tree.val 0]]],
   Tree.branches
     [Tree.branches [Tree.branches [Tree.val 0], Tree.branches [Tree.val 0]],
      Tree.branches [Tree.branches [Tree.val 0], Tree.val 0]]]
```

启用 {option}`guard_msgs.diff` 会高亮显示差异，使错误更加明显：
```lean (error := true) (name := bigMsg')
set_option guard_msgs.diff true in
/--
info: Tree.branches
  [Tree.branches
     [Tree.branches [Tree.branches [Tree.branches [Tree.val 0], Tree.val 0], Tree.branches [Tree.val 0]],
      Tree.branches [Tree.branches [Tree.val 2], Tree.branches [Tree.val 0]]],
   Tree.branches
     [Tree.branches [Tree.branches [Tree.val 0], Tree.branches [Tree.val 0]],
      Tree.branches [Tree.branches [Tree.val 0], Tree.val 0]]]
-/
#guard_msgs in
#eval Tree.big 20
```
```leanOutput bigMsg'  (severity := error)
❌️ Docstring on `#guard_msgs` does not match generated message:

  info: Tree.branches
    [Tree.branches
       [Tree.branches [Tree.branches [Tree.branches [Tree.val 0], Tree.val 0], Tree.branches [Tree.val 0]],
-       Tree.branches [Tree.branches [Tree.val 2], Tree.branches [Tree.val 0]]],
+       Tree.branches [Tree.branches [Tree.val 0], Tree.branches [Tree.val 0]]],
     Tree.branches
       [Tree.branches [Tree.branches [Tree.val 0], Tree.branches [Tree.val 0]],
        Tree.branches [Tree.branches [Tree.val 0], Tree.val 0]]]
```
:::
