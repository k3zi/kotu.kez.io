import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Pagination from './../react-bootstrap-pagination';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import EditModal from './EditModal';
import DeleteModal from './DeleteModal';

class Subtitles extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            otherVideos: [],
            metadata: {
                page: 1,
                per: 15,
                total: 0
            },
            isAudiobook: false,
            showDeleteModal: null,
            showEditModal: null
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch(`/api/admin/subtitles?page=${this.state.metadata.page}&per=${this.state.metadata.per}&audiobook=${this.state.isAudiobook ? 'true': 'false'}`);
        if (response.ok) {
            const otherVideos = await response.json();
            this.setState({ otherVideos: otherVideos.items, metadata: otherVideos.metadata });
        }
    }

    loadPage(page) {
        this.state.metadata.page = page;
        this.load();
    }

    toggleIsAudiobook(e) {
        this.state.isAudiobook = e.target.checked;
        this.loadPage(1);
    }

    async showDeleteModal(video) {
        this.setState({
            showDeleteModal: video
        });
        await this.load();
    }

    async showEditModal(video) {
        this.setState({
            showEditModal: video
        });
        await this.load();
    }

    render() {
        return (
            <div>
                <h2>Admin <small className="text-muted">Subtitles {this.state.metadata.total}</small></h2>
                <Form.Group className='mb-3'>
                    <Form.Check inline type="checkbox" label="Audiobook" name='isAudiobook' defaultChecked={this.state.isAudiobook} onChange={(e) => this.toggleIsAudiobook(e)} />
                </Form.Group>
                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th>Title</th>
                            <th>Source</th>
                            <th>Tags</th>
                            <th className='text-center'># of Subtitles</th>
                            <th className='text-center'>CPS Issues</th>
                            <th className="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.otherVideos.map((otherVideo, i) => {
                            return (<tr key={i}>
                                <td className="align-middle">{otherVideo.title}</td>
                                <td className="align-middle">{otherVideo.source}</td>
                                <td className="align-middle"><div className='d-flex justify-content-between align-items-center'>{otherVideo.tags.map(tag =>
                                    <Badge className='bg-secondary me-1 my-1'>{tag}</Badge>
                                )}</div></td>
                                <td className="align-middle text-center">{otherVideo.count}</td>
                                <td className="align-middle text-center">
                                    <Badge pill className={`me-1 bg-${otherVideo.charactersPerSecondWarningCount > 0 ? 'warning' : 'secondary'}`}>{otherVideo.charactersPerSecondWarningCount}</Badge>
                                    <Badge pill className={`bg-${otherVideo.charactersPerSecondErrorCount > 0 ? 'danger' : 'secondary'}`}>{otherVideo.charactersPerSecondErrorCount}</Badge>
                                </td>
                                <td className="align-middle text-center expand">
                                    <Button className='mt-2 mt-md-0 ms-0 ms-md-2' variant="info" onClick={() => this.showEditModal(otherVideo)}><i className="bi bi-pencil-square"></i></Button>
                                    <div className='w-100 d-block d-md-none'></div>
                                    <Button className='mt-2 mt-md-0 ms-0 ms-md-2' variant="danger" onClick={() => this.showDeleteModal(otherVideo)}><i className="bi bi-trash"></i></Button>
                                </td>
                            </tr>);
                        })}
                    </tbody>
                </Table>
                <Pagination totalPages={Math.ceil(this.state.metadata.total / this.state.metadata.per)} currentPage={this.state.metadata.page} showMax={7} onClick={(i) => this.loadPage(i)} />
                <EditModal
                    title='Edit Video'
                    fields={[
                        { label: 'Title', name: 'title', type: 'text', placeholder: 'Enter the name of the video' }
                    ]}
                    object={this.state.showEditModal}
                    url={this.state.showEditModal && `/api/admin/subtitle/${this.state.showEditModal.id}`}
                    onHide={() => this.showEditModal(null)}
                    onSuccess={() => this.showEditModal(null)}
                />
                <DeleteModal
                    title='Delete Video'
                    object={this.state.showDeleteModal}
                    confirmationMessage={`Are you sure you wish to delete: ${this.state.showDeleteModal && this.state.showDeleteModal.title}?`}
                    url={this.state.showDeleteModal && `/api/admin/subtitle/${this.state.showDeleteModal.id}`}
                    onHide={() => this.showDeleteModal(null)}
                    onSuccess={() => this.showDeleteModal(null)}
                />
            </div>
        );
    }
}

export default Subtitles;
