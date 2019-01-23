module ComputedFieldTypes

export @computed, fulltype

"""
    fulltype(::Type)

Fill in the computed type parameters for `T` (if applicable and possible)
"""
fulltype(T::Type) = T


"""
    @computed type

Allows declaration of a type expression where some of the fields types are arbitrary computed functions of other type parameters.
It's suggested that those expressions be `const` (return the same value for the same inputs), but that is not essential.
"""
macro computed(typeexpr::Expr)
    return esc(_computed(typeexpr)) # macro hygiene is already handled, so escape everything
end

"""
    _computed(typeexpr::Expr)

the bulk of the work to compute the AST transform
"""
function _computed(typeexpr::Expr)
    typeexpr.head === :struct || error("expected a type expression")
    if isa(typeexpr.args[2], Expr) && typeexpr.args[2].head == :(<:)
        curly = make_curly(typeexpr.args[2].args[1])
        typeexpr.args[2].args[1] = curly
    else
        curly = make_curly(typeexpr.args[2])
        typeexpr.args[2] = curly
    end
    tname = curly.args[1]::Symbol

    # extract list of declared type variables
    decl_tvars = Symbol[]
    for i in 2:length(curly.args)
        t = curly.args[i]
        if isa(t, Symbol)
            push!(decl_tvars, t)
        elseif isa(t, Expr) && t.head === :(<:) && isa(t.args[1], Symbol)
            push!(decl_tvars, t.args[1])
        else
            error("unexpected type variable expression")
        end
    end

    # compute fields
    fields = (typeexpr.args[3]::Expr).args
    ctors = Expr[] # non-field expressions
    def = Expr[] # definitions for field-type calculations
    fieldnames = Symbol[]
    for f in fields
        if isa(f, Symbol)
            push!(fieldnames, f.args[1]::Symbol)
        elseif isa(f, Expr)
            if f.head === :(::) && isa(f.args[1], Symbol)
                push!(fieldnames, f.args[1]::Symbol)
                f.args[2] = getenv!(f.args[2], curly.args, def)
            elseif typeof(f) !== :LineNumberNode
                push!(ctors, f)
            end
        end
    end

    # rewrite constructors
    if isempty(ctors)
        # normally, Julia would add 3 default constructors here
        # however, two of those are not computable, so we don't add them
        push!(fields, Expr(:function, Expr(:where, Expr(:call, make_Type_expr(tname, decl_tvars), fieldnames...), decl_tvars...),
                           Expr(:block, Expr(:return, Expr(:call, make_new_expr(:new, decl_tvars, def), fieldnames...)))))
    else
        for e in ctors
            rewrite_new!(e, tname, decl_tvars, def)
        end
    end

    # add some extra function declarations for convenience
    return Expr(:block, typeexpr, make_fulltype_expr(tname, decl_tvars, def))
end

"""
    make_curly(expr)

given an apply-type expression (`T` or `T{...}`), return `Expr(:curly, T, ...)`
"""
make_curly(@nospecialize curly) = error("expected an apply-type expression")
function make_curly(curly::Expr)
    if curly.head !== :curly || !isa(curly.args[1], Symbol)
        make_curly(nothing)
    end
    return curly
end
function make_curly(curly::Symbol)
    return Expr(:curly, curly)
end

"""
    getenv!(expr, tvars, defs)

replace anything that isn't computable by apply_type
with a dummy type-variable
"""
getenv!(@nospecialize(e), tvars, def) = e
function getenv!(e::Expr, tvars, def)
    if e.head === :curly || e.head === :where
        for i = 1:length(e.args)
            e.args[i] = getenv!(e.args[i], tvars, def)
        end
        return e
    else
        v = gensym()
        push!(tvars, v)
        push!(def, e)
        return v
    end
end

"""
    make_Type_expr(tname, decl_tvars)

make the `::Type{T}` expression that is equivalent to the original type declaration
"""
make_Type_expr(tname, decl_tvars) = Expr(:(::), Expr(:curly, Expr(:top, :Type), Expr(:curly, tname, decl_tvars...)))

"""
    make_new_expr(tname, decl_tvars, def) 

compute the leaf `T{...}` expression that describes the new type declaration
"""
make_new_expr(tname, decl_tvars, def) = Expr(:curly, tname, decl_tvars..., def...)

"""
    make_fulltype_expr(tname, decl_tvars, def)

compute the leaf `T{def}` expression that is equivalent for the new type declaration
"""
function make_fulltype_expr(tname, decl_tvars, def)
    return Expr(:function, Expr(:where, Expr(:call, Core.GlobalRef(ComputedFieldTypes, :fulltype), make_Type_expr(tname, decl_tvars)),
                                       decl_tvars...),
                           Expr(:block, Expr(:return, make_new_expr(tname, decl_tvars, def))))
end

"""
    rewrite_new!(expr, tname::Symbol, decl_tvars, def)

rewrite the constructors to capture only the intended values
"""
rewrite_new!(@nospecialize(e), tname::Symbol, decl_tvars, def) = nothing
function rewrite_new!(e::Expr, tname::Symbol, decl_tvars, def)
    if e.head !== :line
        for i = 1:length(e.args)
            rewrite_new!(e.args[i], tname, decl_tvars, def)
        end

        # rewrite any calls to `new()` or `new{...}()` to append our dummy type variables
        if e.head === :call && e.args[1] === :new
            curly = Expr(:curly, e.args[1])
            e.args[1] = curly
            push!(curly.args, decl_tvars...)
            push!(curly.args, def...)
        elseif e.head === :call && isa(e.args[1], Expr) && e.args[1].head === :curly && e.args[1].args[1] === :new
            curly = e.args[1]
            length(curly.args) == length(decl_tvars) + 1 || error("too few type parameters specified in \"new{...}\"")
            push!(curly.args, def...)
        end

        # rewrite constructor declarations to explicitly only involve the declared type-variables
        # this involves rewriting `A` as `(::Type{A{T...}}) where {T...}`
        if e.head === :function || (e.head === :(=) && isa(e.args[1], Expr) && e.args[1].head === :call)
            pfname = e.args[1].args
            if isa(pfname[1], Expr) && pfname[1].head === :curly
                pfname = pfname[1].args
            end
            if pfname[1] === tname
                pfname[1] = make_Type_expr(tname, decl_tvars)
                param = e.args[1].args[1]
                if !(isa(param, Expr) && param.head === :curly)
                    param = Expr(:where, e.args[1])
                    e.args[1] = param
                elseif isa(param, Expr) && param.head === :curly
                    vars = param.args[2:end]
                    param = Expr(:where, Expr(:call, e.args[1].args[1].args[1], e.args[1].args[2]))
                    e.args[1] = param
                    append!(param.args, vars)
                end
                append!(param.args, decl_tvars)
            end
        end
    end
    nothing
end

end
