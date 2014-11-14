package away3d.core.base;


import away3d.utils.ArrayUtils;
import openfl.errors.Error;
import away3d.core.managers.Stage3DProxy;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DVertexBufferFormat;
import openfl.display3D.VertexBuffer3D;
import openfl.geom.Matrix3D;

import openfl.utils.Float32Array;

class CompactSubGeometry extends SubGeometryBase implements ISubGeometry {
    public var numVertices(get_numVertices, never):Int;
    public var secondaryUVStride(get_secondaryUVStride, never):Int;
    public var secondaryUVOffset(get_secondaryUVOffset, never):Int;

    private var _vertexDataInvalid:Array<Bool>;
    private var _vertexBuffer:Array<VertexBuffer3D>;
    private var _bufferContext:Array<Context3D>;
    private var _numVertices:Int;
    private var _contextIndex:Int;
    private var _activeBuffer:VertexBuffer3D;
    private var _activeContext:Context3D;
    private var _activeDataInvalid:Bool;
    private var _isolatedVertexPositionData:Float32Array;
    private var _isolatedVertexPositionDataDirty:Bool;

    public function new() {
        super();
        _vertexDataInvalid = ArrayUtils.Prefill( new Array<Bool>(), 8 );
        _vertexBuffer = ArrayUtils.Prefill( new Array<VertexBuffer3D>(), 8 );
        _bufferContext = ArrayUtils.Prefill( new Array<Context3D>(), 8 );
        _autoDeriveVertexNormals = false;
        _autoDeriveVertexTangents = false;
    }

    public function get_numVertices():Int {
        return _numVertices;
    }

    /**
	 * Updates the vertex data. All vertex properties are contained in a single Vector, and the order is as follows:
	 * 0 - 2: vertex position X, Y, Z
	 * 3 - 5: normal X, Y, Z
	 * 6 - 8: tangent X, Y, Z
	 * 9 - 10: U V
	 * 11 - 12: Secondary U V
	 */
    public function updateData(data:Float32Array):Void {
        if (_autoDeriveVertexNormals) _vertexNormalsDirty = true;
        if (_autoDeriveVertexTangents) _vertexTangentsDirty = true;
        _faceNormalsDirty = true;
        _faceTangentsDirty = true;
        _isolatedVertexPositionDataDirty = true;
        _vertexData = data;
        var numVertices:Int = Std.int(_vertexData.length / 13);
        if (numVertices != _numVertices) disposeVertexBuffers(_vertexBuffer);
        _numVertices = numVertices;
        if (_numVertices == 0) throw new Error("Bad data: geometry can't have zero triangles");
        invalidateBuffers(_vertexDataInvalid);
        invalidateBounds();
    }

    public function activateVertexBuffer(index:Int, stage3DProxy:Stage3DProxy):Void {
        var contextIndex:Int = stage3DProxy._stage3DIndex;
        var context:Context3D = stage3DProxy._context3D;
        if (contextIndex != _contextIndex) updateActiveBuffer(contextIndex);
        if (_activeBuffer == null || _activeContext != context) createBuffer(contextIndex, context);
        if (_activeDataInvalid) uploadData(contextIndex);
		//todo 
		//trace(index, _vertexData, 0, Context3DVertexBufferFormat.FLOAT_3);
        context.setVertexBufferAt(index, _activeBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
    }

    public function activateUVBuffer(index:Int, stage3DProxy:Stage3DProxy):Void {
        var contextIndex:Int = stage3DProxy._stage3DIndex;
        var context:Context3D = stage3DProxy._context3D;
        if (_uvsDirty && _autoGenerateUVs) {
            _vertexData = updateDummyUVs(_vertexData);
            invalidateBuffers(_vertexDataInvalid);
        }
        if (contextIndex != _contextIndex) updateActiveBuffer(contextIndex);
        if (_activeBuffer == null || _activeContext != context) createBuffer(contextIndex, context);
        if (_activeDataInvalid) uploadData(contextIndex);
        context.setVertexBufferAt(index, _activeBuffer, 9, Context3DVertexBufferFormat.FLOAT_2);
    }

    public function activateSecondaryUVBuffer(index:Int, stage3DProxy:Stage3DProxy):Void {
        var contextIndex:Int = stage3DProxy._stage3DIndex;
        var context:Context3D = stage3DProxy._context3D;
        if (contextIndex != _contextIndex) updateActiveBuffer(contextIndex);
        if (_activeBuffer == null || _activeContext != context) createBuffer(contextIndex, context);
        if (_activeDataInvalid) uploadData(contextIndex);
        context.setVertexBufferAt(index, _activeBuffer, 11, Context3DVertexBufferFormat.FLOAT_2);
    }

    private function uploadData(contextIndex:Int):Void {
        //trace("_numVertices"+_numVertices+"  _vertexData:"+_vertexData);
        _activeBuffer.uploadFromFloat32Array(_vertexData, 0, _numVertices);
        _vertexDataInvalid[contextIndex] = _activeDataInvalid = false;
    }

    public function activateVertexNormalBuffer(index:Int, stage3DProxy:Stage3DProxy):Void {
        var contextIndex:Int = stage3DProxy._stage3DIndex;
        var context:Context3D = stage3DProxy._context3D;
        if (contextIndex != _contextIndex) updateActiveBuffer(contextIndex);
        if (_activeBuffer == null || _activeContext != context) createBuffer(contextIndex, context);
        if (_activeDataInvalid) uploadData(contextIndex);
        context.setVertexBufferAt(index, _activeBuffer, 3, Context3DVertexBufferFormat.FLOAT_3);
    }

    public function activateVertexTangentBuffer(index:Int, stage3DProxy:Stage3DProxy):Void {
        var contextIndex:Int = stage3DProxy._stage3DIndex;
        var context:Context3D = stage3DProxy._context3D;
        if (contextIndex != _contextIndex) updateActiveBuffer(contextIndex);
        if (_activeBuffer == null || _activeContext != context) createBuffer(contextIndex, context);
        if (_activeDataInvalid) uploadData(contextIndex);
        context.setVertexBufferAt(index, _activeBuffer, 6, Context3DVertexBufferFormat.FLOAT_3);
    }

    private function createBuffer(contextIndex:Int, context:Context3D):Void {
        _vertexBuffer[contextIndex] = _activeBuffer = context.createVertexBuffer(_numVertices, 13);
        _bufferContext[contextIndex] = _activeContext = context;
        _vertexDataInvalid[contextIndex] = _activeDataInvalid = true;
    }

    private function updateActiveBuffer(contextIndex:Int):Void {
        _contextIndex = contextIndex;
        _activeDataInvalid = _vertexDataInvalid[contextIndex];
        _activeBuffer = _vertexBuffer[contextIndex];
        _activeContext = _bufferContext[contextIndex];
    }

    override public function get_vertexData():Float32Array {
        if (_autoDeriveVertexNormals && _vertexNormalsDirty) _vertexData = updateVertexNormals(_vertexData);
        if (_autoDeriveVertexTangents && _vertexTangentsDirty) _vertexData = updateVertexTangents(_vertexData);
        if (_uvsDirty && _autoGenerateUVs) _vertexData = updateDummyUVs(_vertexData);
        return _vertexData;
    }

    override private function updateVertexNormals(target:Float32Array):Float32Array {
        invalidateBuffers(_vertexDataInvalid);
        return super.updateVertexNormals(target);
    }

    override private function updateVertexTangents(target:Float32Array):Float32Array {
        if (_vertexNormalsDirty) _vertexData = updateVertexNormals(_vertexData);
        invalidateBuffers(_vertexDataInvalid);
        return super.updateVertexTangents(target);
    }

    override public function get_vertexNormalData():Float32Array {
        if (_autoDeriveVertexNormals && _vertexNormalsDirty) _vertexData = updateVertexNormals(_vertexData);
        return _vertexData;
    }

    override public function get_vertexTangentData():Float32Array {
        if (_autoDeriveVertexTangents && _vertexTangentsDirty) _vertexData = updateVertexTangents(_vertexData);
        return _vertexData;
    }

    override public function get_UVData():Float32Array {
        if (_uvsDirty && _autoGenerateUVs) {
            _vertexData = updateDummyUVs(_vertexData);
            invalidateBuffers(_vertexDataInvalid);
        }
        return _vertexData;
    }

    override public function applyTransformation(transform:Matrix3D):Void {
        super.applyTransformation(transform);
        invalidateBuffers(_vertexDataInvalid);
    }

    override public function scale(scale:Float):Void {
        super.scale(scale);
        invalidateBuffers(_vertexDataInvalid);
    }

    public function clone():ISubGeometry {
        var clone:CompactSubGeometry = new CompactSubGeometry();
        clone._autoDeriveVertexNormals = _autoDeriveVertexNormals;
        clone._autoDeriveVertexTangents = _autoDeriveVertexTangents;
        clone.updateData(_vertexData.copy());
        clone.updateIndexData(_indices.copy());
        return clone;
    }

    override public function scaleUV(scaleU:Float = 1, scaleV:Float = 1):Void {
        super.scaleUV(scaleU, scaleV);
        invalidateBuffers(_vertexDataInvalid);
    }

    override public function get_vertexStride():Int {
        return 13;
    }

    override public function get_vertexNormalStride():Int {
        return 13;
    }

    override public function get_vertexTangentStride():Int {
        return 13;
    }

    override public function get_UVStride():Int {
        return 13;
    }

    public function get_secondaryUVStride():Int {
        return 13;
    }

    override public function get_vertexOffset():Int {
        return 0;
    }

    override public function get_vertexNormalOffset():Int {
        return 3;
    }

    override public function get_vertexTangentOffset():Int {
        return 6;
    }

    override public function get_UVOffset():Int {
        return 9;
    }

    public function get_secondaryUVOffset():Int {
        return 11;
    }

    override public function dispose():Void {
        super.dispose();
        disposeVertexBuffers(_vertexBuffer);
        _vertexBuffer = null;
    }

    override private function disposeVertexBuffers(buffers:Array<VertexBuffer3D>):Void {
        super.disposeVertexBuffers(buffers);
        _activeBuffer = null;
    }

    override private function invalidateBuffers(invalid:Array<Bool>):Void {
        super.invalidateBuffers(invalid);
        _activeDataInvalid = true;
    }

    public function cloneWithSeperateBuffers():SubGeometry {
        var clone:SubGeometry = new SubGeometry();
        clone.updateVertexData((_isolatedVertexPositionData != null) ? _isolatedVertexPositionData : _isolatedVertexPositionData = stripBuffer(0, 3));
        clone.autoDeriveVertexNormals = _autoDeriveVertexNormals;
        clone.autoDeriveVertexTangents = _autoDeriveVertexTangents;
        if (!_autoDeriveVertexNormals) clone.updateVertexNormalData(stripBuffer(3, 3));
        if (!_autoDeriveVertexTangents) clone.updateVertexTangentData(stripBuffer(6, 3));
        clone.updateUVData(stripBuffer(9, 2));
        clone.updateSecondaryUVData(stripBuffer(11, 2));
        clone.updateIndexData(indexData.copy());
        return clone;
    }

    override public function get_vertexPositionData():Float32Array {
        if (_isolatedVertexPositionDataDirty || _isolatedVertexPositionData == null) {
            _isolatedVertexPositionData = stripBuffer(0, 3);
            _isolatedVertexPositionDataDirty = false;
        }
        return _isolatedVertexPositionData;
    }

    /**
	 * Isolate and returns a Vector.Number of a specific buffer type
	 *
	 * - stripBuffer(0, 3), return only the vertices
	 * - stripBuffer(3, 3): return only the normals
	 * - stripBuffer(6, 3): return only the tangents
	 * - stripBuffer(9, 2): return only the uv's
	 * - stripBuffer(11, 2): return only the secondary uv's
	 */
    public function stripBuffer(offset:Int, numEntries:Int):Float32Array {
        //var data:Array<Float> = ArrayUtils.Prefill( new Array<Float>(), _numVertices * numEntries);
        var data:Float32Array = new Float32Array( _numVertices * numEntries );
        var i:Int = 0;
        var j:Int = offset;
        var skip:Int = 13 - numEntries;
        var v:Int = 0;
        while (v < _numVertices) {
            var k:Int = 0;
            while (k < numEntries) {
                data[i++] = _vertexData[j++];
                ++k;
            }
            j += skip;
            ++v;
        }
        return data;
    }

    public function fromVectors(verts:Float32Array, uvs:Float32Array, normals:Float32Array, tangents:Float32Array):Void {
        var vertLen:Int = Std.int(verts.length / 3 * 13);
        var index:Int = 0;
        var v:Int = 0;
        var n:Int = 0;
        var t:Int = 0;
        var u:Int = 0;
        //var data:Float32Array = ArrayUtils.Prefill( new Array<Float>(), vertLen, 0);
        var data:Float32Array = new Float32Array( vertLen );
        while (index < vertLen) {
            data[index++] = verts[v++];
            data[index++] = verts[v++];
            data[index++] = verts[v++];
            if (normals != null && normals.length > 0) {
                data[index++] = normals[n++];
                data[index++] = normals[n++];
                data[index++] = normals[n++];
            }

            else {
                data[index++] = 0;
                data[index++] = 0;
                data[index++] = 0;
            }

            if (tangents != null && tangents.length > 0) {
                data[index++] = tangents[t++];
                data[index++] = tangents[t++];
                data[index++] = tangents[t++];
            }

            else {
                data[index++] = 0;
                data[index++] = 0;
                data[index++] = 0;
            }

            if (uvs != null && uvs.length > 0) {
                data[index++] = uvs[u];
                data[index++] = uvs[u + 1];
                // use same secondary uvs as primary
                data[index++] = uvs[u++];
                data[index++] = uvs[u++];
            }

            else {
                data[index++] = 0;
                data[index++] = 0;
                data[index++] = 0;
                data[index++] = 0;
            }

        }

        autoDeriveVertexNormals = !(normals != null && normals.length > 0);
        autoDeriveVertexTangents = !(tangents != null && tangents.length > 0);
        autoGenerateDummyUVs = !(uvs != null && uvs.length > 0);
        updateData(data);
    }
}

