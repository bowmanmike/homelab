defmodule Homelab.Compose.Lock do
  @moduledoc """
  Single-flight lock for compose operations.

  Only one compose operation (pull, up, recreate) can run at a time to prevent
  race conditions. Callers that can't acquire the lock within the timeout
  receive an error so the UI can inform the user.
  """

  use GenServer

  @type acquire_result :: :ok | {:error, :timeout}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Attempts to acquire the lock. Blocks up to `timeout` ms.

  Returns `:ok` if acquired, `{:error, :timeout}` if another operation holds
  the lock and didn't release in time.
  """
  @spec acquire(timeout()) :: acquire_result()
  def acquire(timeout \\ 5_000) do
    GenServer.call(__MODULE__, {:acquire, self()}, timeout)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
  end

  @doc """
  Releases the lock. Only the current owner can release.
  """
  @spec release() :: :ok
  def release do
    GenServer.call(__MODULE__, {:release, self()})
  end

  ## Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{owner: nil, waiting: :queue.new()}}
  end

  @impl true
  def handle_call({:acquire, pid}, _from, %{owner: nil} = state) do
    ref = Process.monitor(pid)
    {:reply, :ok, %{state | owner: {pid, ref}}}
  end

  def handle_call({:acquire, pid}, from, %{owner: {_owner_pid, _}, waiting: queue} = state) do
    {:noreply, %{state | waiting: :queue.in({from, pid}, queue)}}
  end

  def handle_call({:release, pid}, _from, %{owner: {pid, ref}} = state) do
    Process.demonitor(ref, [:flush])
    state = grant_next_waiter(%{state | owner: nil})
    {:reply, :ok, state}
  end

  def handle_call({:release, _pid}, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, %{owner: {pid, ref}} = state) do
    state = grant_next_waiter(%{state | owner: nil})
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{waiting: queue} = state) do
    queue = :queue.filter(fn {_from, waiter_pid} -> waiter_pid != pid end, queue)
    {:noreply, %{state | waiting: queue}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp grant_next_waiter(%{waiting: queue} = state) do
    case :queue.out(queue) do
      {:empty, _} ->
        state

      {{:value, {from, pid}}, rest} ->
        ref = Process.monitor(pid)
        GenServer.reply(from, :ok)
        %{state | owner: {pid, ref}, waiting: rest}
    end
  end
end
